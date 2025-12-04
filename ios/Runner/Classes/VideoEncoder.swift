// ios/Runner/VideoEncoder.swift

import Foundation
import AVFoundation
import VideoToolbox

/**
 * iOS H.264视频编码器
 * 使用VideoToolbox硬件编码器
 */
class VideoEncoder {
    private var compressionSession: VTCompressionSession?
    private var width: Int32 = 0
    private var height: Int32 = 0
    private var isInitialized = false
    private var encodedData: Data?
    private let encodeLock = NSLock()
    
    /**
     * 初始化编码器
     */
    func initialize(width: Int, height: Int, fps: Int, bitrate: Int) -> Bool {
        if isInitialized {
            print("VideoEncoder: 编码器已初始化")
            return true
        }
        
        self.width = Int32(width)
        self.height = Int32(height)
        
        print("VideoEncoder: 初始化编码器 \(width)x\(height), fps=\(fps), bitrate=\(bitrate)")
        
        // 创建压缩会话
        var session: VTCompressionSession?
        let status = VTCompressionSessionCreate(
            allocator: kCFAllocatorDefault,
            width: self.width,
            height: self.height,
            codecType: kCMVideoCodecType_H264,
            encoderSpecification: nil,
            imageBufferAttributes: nil,
            compressedDataAllocator: nil,
            outputCallback: compressionOutputCallback,
            refcon: Unmanaged.passUnretained(self).toOpaque(),
            compressionSessionOut: &session
        )
        
        guard status == noErr, let session = session else {
            print("VideoEncoder: 创建压缩会话失败: \(status)")
            return false
        }
        
        compressionSession = session
        
        // 设置编码器属性
        VTSessionSetProperty(session, key: kVTCompressionPropertyKey_RealTime, value: kCFBooleanTrue)
        VTSessionSetProperty(session, key: kVTCompressionPropertyKey_ProfileLevel, value: kVTProfileLevel_H264_Baseline_AutoLevel)
        VTSessionSetProperty(session, key: kVTCompressionPropertyKey_AverageBitRate, value: bitrate as CFTypeRef)
        VTSessionSetProperty(session, key: kVTCompressionPropertyKey_ExpectedFrameRate, value: fps as CFTypeRef)
        VTSessionSetProperty(session, key: kVTCompressionPropertyKey_MaxKeyFrameInterval, value: fps as CFTypeRef) // 1秒一个关键帧
        VTSessionSetProperty(session, key: kVTCompressionPropertyKey_AllowFrameReordering, value: kCFBooleanFalse)
        
        // 准备编码
        let prepareStatus = VTCompressionSessionPrepareToEncodeFrames(session)
        if prepareStatus != noErr {
            print("VideoEncoder: 准备编码失败: \(prepareStatus)")
            release()
            return false
        }
        
        isInitialized = true
        print("VideoEncoder: 编码器初始化成功")
        return true
    }
    
    /**
     * 编码单帧YUV420数据
     */
    func encodeFrame(yuvData: Data) -> Data? {
        guard isInitialized, let session = compressionSession else {
            print("VideoEncoder: 编码器未初始化")
            return nil
        }
        
        encodeLock.lock()
        defer { encodeLock.unlock() }
        
        // 创建CVPixelBuffer
        var pixelBuffer: CVPixelBuffer?
        let status = CVPixelBufferCreate(
            kCFAllocatorDefault,
            Int(width),
            Int(height),
            kCVPixelFormatType_420YpCbCr8BiPlanarFullRange,
            nil,
            &pixelBuffer
        )
        
        guard status == kCVReturnSuccess, let pixelBuffer = pixelBuffer else {
            print("VideoEncoder: 创建PixelBuffer失败: \(status)")
            return nil
        }
        
        // 填充YUV数据到PixelBuffer
        CVPixelBufferLockBaseAddress(pixelBuffer, [])
        defer { CVPixelBufferUnlockBaseAddress(pixelBuffer, []) }
        
        let ySize = Int(width * height)
        let uSize = ySize / 4
        let vSize = ySize / 4
        
        // 填充Y平面
        if let yPlane = CVPixelBufferGetBaseAddressOfPlane(pixelBuffer, 0) {
            let yStride = CVPixelBufferGetBytesPerRowOfPlane(pixelBuffer, 0)
            let yPlanePtr = yPlane.assumingMemoryBound(to: UInt8.self)
            
            yuvData.withUnsafeBytes { rawBufferPointer in
                let yDataPtr = rawBufferPointer.baseAddress!.assumingMemoryBound(to: UInt8.self)
                
                // 逐行复制Y数据
                for row in 0..<Int(height) {
                    let srcOffset = row * Int(width)
                    let dstOffset = row * yStride
                    memcpy(yPlanePtr + dstOffset, yDataPtr + srcOffset, Int(width))
                }
            }
        }
        
        // 填充UV平面（NV12格式：UV交错）
        // 输入是I420格式（Y、U、V分离），需要转换为NV12（UV交错）
        if let uvPlane = CVPixelBufferGetBaseAddressOfPlane(pixelBuffer, 1) {
            let uvStride = CVPixelBufferGetBytesPerRowOfPlane(pixelBuffer, 1)
            let uvPlanePtr = uvPlane.assumingMemoryBound(to: UInt8.self)
            let uvWidth = Int(width) / 2
            let uvHeight = Int(height) / 2
            
            yuvData.withUnsafeBytes { rawBufferPointer in
                let dataPtr = rawBufferPointer.baseAddress!.assumingMemoryBound(to: UInt8.self)
                let uDataPtr = dataPtr + ySize
                let vDataPtr = dataPtr + ySize + uSize
                
                // 交错复制U和V数据
                for row in 0..<uvHeight {
                    for col in 0..<uvWidth {
                        let srcOffset = row * uvWidth + col
                        let dstOffset = row * uvStride + col * 2
                        
                        uvPlanePtr[dstOffset] = uDataPtr[srcOffset]      // U
                        uvPlanePtr[dstOffset + 1] = vDataPtr[srcOffset]  // V
                    }
                }
            }
        }
        
        // 编码帧
        encodedData = nil
        let presentationTimeStamp = CMTime(value: CMTimeValue(Date().timeIntervalSince1970 * 1000000), timescale: 1000000)
        
        let encodeStatus = VTCompressionSessionEncodeFrame(
            session,
            imageBuffer: pixelBuffer,
            presentationTimeStamp: presentationTimeStamp,
            duration: .invalid,
            frameProperties: nil,
            sourceFrameRefcon: Unmanaged.passUnretained(self).toOpaque(),
            infoFlagsOut: nil
        )
        
        if encodeStatus != noErr {
            print("VideoEncoder: 编码帧失败: \(encodeStatus)")
            return nil
        }
        
        // 等待编码完成
        VTCompressionSessionCompleteFrames(session, untilPresentationTimeStamp: .invalid)
        
        // 获取编码数据
        if let data = encodedData {
            print("VideoEncoder: 编码成功 输入\(yuvData.count)字节, 输出\(data.count)字节")
            return data
        }
        
        return nil
    }
    
    /**
     * 编码回调
     */
    fileprivate func didCompressFrame(status: OSStatus, infoFlags: VTEncodeInfoFlags, sampleBuffer: CMSampleBuffer?) {
        guard status == noErr, let sampleBuffer = sampleBuffer else {
            print("VideoEncoder: 编码回调失败: \(status)")
            return
        }
        
        guard let dataBuffer = CMSampleBufferGetDataBuffer(sampleBuffer) else {
            print("VideoEncoder: 获取数据缓冲区失败")
            return
        }
        
        var length: Int = 0
        var dataPointer: UnsafeMutablePointer<Int8>?
        let statusCode = CMBlockBufferGetDataPointer(dataBuffer, atOffset: 0, lengthAtOffsetOut: nil, totalLengthOut: &length, dataPointerOut: &dataPointer)
        
        guard statusCode == kCMBlockBufferNoErr, let dataPointer = dataPointer else {
            print("VideoEncoder: 获取数据指针失败")
            return
        }
        
        // 提取H.264数据
        var h264Data = Data()
        
        // 添加SPS和PPS（如果是关键帧）
        if let attachments = CMSampleBufferGetSampleAttachmentsArray(sampleBuffer, createIfNecessary: false) as? [[CFString: Any]],
           let attachment = attachments.first,
           let dependsOnOthers = attachment[kCMSampleAttachmentKey_DependsOnOthers] as? Bool,
           !dependsOnOthers {
            // 关键帧，添加SPS和PPS
            if let formatDescription = CMSampleBufferGetFormatDescription(sampleBuffer) {
                var parameterSetCount: Int = 0
                CMVideoFormatDescriptionGetH264ParameterSetAtIndex(formatDescription, parameterSetIndex: 0, parameterSetPointerOut: nil, parameterSetSizeOut: nil, parameterSetCountOut: &parameterSetCount, nalUnitHeaderLengthOut: nil)
                
                for i in 0..<parameterSetCount {
                    var parameterSetPointer: UnsafePointer<UInt8>?
                    var parameterSetSize: Int = 0
                    CMVideoFormatDescriptionGetH264ParameterSetAtIndex(formatDescription, parameterSetIndex: i, parameterSetPointerOut: &parameterSetPointer, parameterSetSizeOut: &parameterSetSize, parameterSetCountOut: nil, nalUnitHeaderLengthOut: nil)
                    
                    if let parameterSetPointer = parameterSetPointer {
                        // 添加起始码
                        h264Data.append(contentsOf: [0x00, 0x00, 0x00, 0x01])
                        h264Data.append(parameterSetPointer, count: parameterSetSize)
                    }
                }
            }
        }
        
        // 添加NALU数据（替换长度字段为起始码）
        var offset = 0
        while offset < length - 4 {
            var naluLength: UInt32 = 0
            memcpy(&naluLength, dataPointer + offset, 4)
            naluLength = CFSwapInt32BigToHost(naluLength)
            
            // 添加起始码
            h264Data.append(contentsOf: [0x00, 0x00, 0x00, 0x01])
            
            // 添加NALU数据
            let naluPointer = UnsafeRawPointer(dataPointer + offset + 4).assumingMemoryBound(to: UInt8.self)
            h264Data.append(naluPointer, count: Int(naluLength))
            
            offset += 4 + Int(naluLength)
        }
        
        encodedData = h264Data
    }
    
    /**
     * 释放编码器资源
     */
    func release() {
        if let session = compressionSession {
            VTCompressionSessionInvalidate(session)
            compressionSession = nil
        }
        isInitialized = false
        print("VideoEncoder: 编码器已释放")
    }
}

// 编码回调函数
private func compressionOutputCallback(
    outputCallbackRefCon: UnsafeMutableRawPointer?,
    sourceFrameRefCon: UnsafeMutableRawPointer?,
    status: OSStatus,
    infoFlags: VTEncodeInfoFlags,
    sampleBuffer: CMSampleBuffer?
) {
    guard let sourceFrameRefCon = sourceFrameRefCon else { return }
    let encoder = Unmanaged<VideoEncoder>.fromOpaque(sourceFrameRefCon).takeUnretainedValue()
    encoder.didCompressFrame(status: status, infoFlags: infoFlags, sampleBuffer: sampleBuffer)
}