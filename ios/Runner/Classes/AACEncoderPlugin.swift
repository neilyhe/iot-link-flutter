import Flutter
import UIKit
import AVFoundation
import AudioToolbox

public class AACEncoderPlugin: NSObject, FlutterPlugin {
    private var encoderChannel: FlutterMethodChannel?
    private var eventSink: FlutterEventSink?
    private var audioConverter: AudioConverterRef?
    private var pcmBuffer: Data = Data()
    
    // AAC编码参数
    private let sampleRate: Double = 16000
    private let channels: UInt32 = 1
    private let bitRate: UInt32 = 32000  // 16kHz单声道推荐使用32kbps（范围：8-48kbps）
    
    // 串行队列：确保编码操作按顺序执行，避免数据竞争
    private let encoderQueue = DispatchQueue(label: "com.aac.encoder.queue", qos: .userInitiated)
    
    // 调试标志：用于控制ADTS头的首次打印
    private var firstFrame = true
    
    public static func register(with registrar: FlutterPluginRegistrar) {
        let channel = FlutterMethodChannel(name: "aac_encoder", binaryMessenger: registrar.messenger())
        let instance = AACEncoderPlugin()
        instance.encoderChannel = channel
        registrar.addMethodCallDelegate(instance, channel: channel)
        
        // 注册EventChannel用于流式数据传输
        let eventChannel = FlutterEventChannel(name: "aac_encoder/stream", binaryMessenger: registrar.messenger())
        eventChannel.setStreamHandler(instance)
    }
    
    public func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        switch call.method {
        case "initEncoder":
            initEncoder(result: result)
        case "encodePCM":
            if let args = call.arguments as? [String: Any],
               let pcmData = args["pcmData"] as? FlutterStandardTypedData {
                // 复制数据，避免数据生命周期问题
                let dataCopy = Data(pcmData.data)
                
                // 所有对 pcmBuffer 的访问都必须在串行队列中进行，确保线程安全
                encoderQueue.async {
                    self.pcmBuffer.append(dataCopy)
                    self.encodePCM(result: result)
                }
            } else {
                result(FlutterError(code: "INVALID_ARGUMENT", message: "Invalid PCM data", details: nil))
            }
        case "releaseEncoder":
            releaseEncoder(result: result)
        default:
            result(FlutterMethodNotImplemented)
        }
    }
    
    private func initEncoder(result: @escaping FlutterResult) {
        // 释放旧的编码器
        if audioConverter != nil {
            AudioConverterDispose(audioConverter!)
            audioConverter = nil
        }
        
        // 配置输入格式（PCM）- 必须精确匹配record插件的输出格式
        var inputFormat = AudioStreamBasicDescription()
        inputFormat.mSampleRate = sampleRate
        inputFormat.mFormatID = kAudioFormatLinearPCM
        inputFormat.mFormatFlags = kLinearPCMFormatFlagIsSignedInteger | kLinearPCMFormatFlagIsPacked
        inputFormat.mBytesPerPacket = 2  // 16bit = 2字节每样本
        inputFormat.mFramesPerPacket = 1  // PCM每个packet包含1帧
        inputFormat.mBytesPerFrame = 2  // 16bit单声道 = 2字节每帧
        inputFormat.mChannelsPerFrame = channels
        inputFormat.mBitsPerChannel = 16
        inputFormat.mReserved = 0
        
        // 配置输出格式（AAC）
        var outputFormat = AudioStreamBasicDescription()
        outputFormat.mSampleRate = sampleRate
        outputFormat.mFormatID = kAudioFormatMPEG4AAC
        outputFormat.mFormatFlags = 0  // AAC-LC默认不需要特殊标志
        outputFormat.mBytesPerPacket = 0  // 可变大小
        outputFormat.mFramesPerPacket = 1024  // AAC每帧1024个样本
        outputFormat.mBytesPerFrame = 0  // 可变大小
        outputFormat.mChannelsPerFrame = channels
        outputFormat.mBitsPerChannel = 0  // 压缩格式不适用
        outputFormat.mReserved = 0
        
        // 创建音频转换器
        var converter: AudioConverterRef?
        let status = AudioConverterNew(&inputFormat, &outputFormat, &converter)
        
        if status != noErr {
            result(FlutterError(code: "ENCODER_INIT_FAILED", 
                              message: "Failed to create audio converter: \(status)", 
                              details: nil))
            return
        }
        
        guard let validConverter = converter else {
            result(FlutterError(code: "ENCODER_INIT_FAILED", 
                              message: "Audio converter is nil", 
                              details: nil))
            return
        }
        
        audioConverter = validConverter
        
        // 获取实际的输出格式（在设置比特率之前）
        var actualOutputFormat = AudioStreamBasicDescription()
        var size = UInt32(MemoryLayout<AudioStreamBasicDescription>.size)
        let getFormatStatus = AudioConverterGetProperty(
            audioConverter!,
            kAudioConverterCurrentOutputStreamDescription,
            &size,
            &actualOutputFormat
        )
        
        // 验证输出格式是否有效
        if getFormatStatus != noErr || actualOutputFormat.mSampleRate == 0 || actualOutputFormat.mChannelsPerFrame == 0 {
            AudioConverterDispose(audioConverter!)
            audioConverter = nil
            result(FlutterError(code: "ENCODER_INIT_FAILED", 
                              message: "Invalid output format", 
                              details: nil))
            return
        }

        // 设置比特率（可选，如果失败则使用系统默认值）
        var bitRateValue = bitRate
        let setBitRateStatus = AudioConverterSetProperty(
            audioConverter!,
            kAudioConverterEncodeBitRate,
            UInt32(MemoryLayout<UInt32>.size),
            &bitRateValue
        )

        // 设置比特率（如果失败则使用系统默认值）
        if setBitRateStatus != noErr {
            print("[AACEncoder] 使用系统默认比特率")
        }
        
        result(true)
    }
    
    private func encodePCM(result: @escaping FlutterResult) {
        guard let converter = audioConverter else {
            result(FlutterError(code: "ENCODER_NOT_INITIALIZED", 
                              message: "Encoder not initialized", 
                              details: nil))
            return
        }
        
        // 数据已经在主线程添加到缓冲区，这里直接处理
        // AAC每帧需要1024个样本，每个样本2字节（16bit），单声道
        let samplesPerFrame = 1024
        let bytesPerFrame = samplesPerFrame * 2 * Int(channels)  // 2048 bytes
        
        var aacDataList: [Data] = []
        
        // 批量处理缓冲区中的所有完整帧，避免延迟累积
        while pcmBuffer.count >= bytesPerFrame {
            let frameData = pcmBuffer.prefix(bytesPerFrame)
            pcmBuffer.removeFirst(bytesPerFrame)
            
            // 编码这一帧（包含ADTS头）
            if let aacData = encodeFrame(converter: converter, pcmData: frameData) {
                aacDataList.append(aacData)
            }
        }
        
        // Flutter要求result回调必须在主线程执行
        if aacDataList.isEmpty {
            DispatchQueue.main.async {
                result(nil)
            }
        } else {
            // 合并所有AAC数据
            var combinedData = Data()
            for aacData in aacDataList {
                combinedData.append(aacData)
            }
            DispatchQueue.main.async {
                result(FlutterStandardTypedData(bytes: combinedData))
            }
        }
    }
    
    private func encodeFrame(converter: AudioConverterRef, pcmData: Data) -> Data? {
        // 使用NSData确保数据在整个编码过程中保持有效
        let pcmNSData = pcmData as NSData
        
        // 准备输入回调的上下文
        let inputDataProc: AudioConverterComplexInputDataProc = { (
            inAudioConverter,
            ioNumberDataPackets,
            ioData,
            outDataPacketDescription,
            inUserData
        ) -> OSStatus in
            let context = inUserData!.assumingMemoryBound(to: AudioBufferContext.self)
            
            // 检查是否已经提供过数据
            if context.pointee.dataProvided {
                ioNumberDataPackets.pointee = 0
                return -1  // 表示没有更多数据
            }
            
            let totalBytes = context.pointee.dataSize
            let requestedPackets = Int(ioNumberDataPackets.pointee)
            
            // PCM格式：每个packet = 1帧 = 1个样本 = 2字节（16bit单声道）
            let availablePackets = totalBytes / 2
            let packetsToProvide = min(availablePackets, requestedPackets)
            
            if packetsToProvide == 0 {
                ioNumberDataPackets.pointee = 0
                return -1
            }
            
            // 设置返回的packet数量
            ioNumberDataPackets.pointee = UInt32(packetsToProvide)
            
            // 填充音频缓冲区
            ioData.pointee.mNumberBuffers = 1
            ioData.pointee.mBuffers.mData = context.pointee.dataPtr
            ioData.pointee.mBuffers.mDataByteSize = UInt32(packetsToProvide * 2)  // 每个packet 2字节
            ioData.pointee.mBuffers.mNumberChannels = context.pointee.channels
            
            // 标记数据已提供
            context.pointee.dataProvided = true
            
            return noErr
        }
        
        // 创建上下文
        var context = AudioBufferContext(
            dataPtr: UnsafeMutableRawPointer(mutating: pcmNSData.bytes),
            dataSize: pcmData.count,
            channels: channels,
            dataProvided: false
        )
        
        // 准备输出缓冲区（AAC帧通常小于768字节）
        let outputBufferSize = 1024 * 2
        var outputBuffer = Data(count: outputBufferSize)
        
        var outputBufferList = AudioBufferList()
        outputBufferList.mNumberBuffers = 1
        outputBufferList.mBuffers.mNumberChannels = channels
        outputBufferList.mBuffers.mDataByteSize = UInt32(outputBufferSize)
        
        return outputBuffer.withUnsafeMutableBytes { outputBytes in
            outputBufferList.mBuffers.mData = outputBytes.baseAddress
            
            var ioOutputDataPacketSize: UInt32 = 1  // 请求1个AAC包
            var outputPacketDescriptions = AudioStreamPacketDescription()
            
            let status = AudioConverterFillComplexBuffer(
                converter,
                inputDataProc,
                &context,
                &ioOutputDataPacketSize,
                &outputBufferList,
                &outputPacketDescriptions
            )
            
            if status == noErr && ioOutputDataPacketSize > 0 {
                let aacDataSize = Int(outputPacketDescriptions.mDataByteSize)
                let aacRawData = Data(bytes: outputBytes.baseAddress!, count: aacDataSize)
                
                // 为AAC数据添加ADTS头
                let adtsHeader = createADTSHeader(dataLength: aacDataSize)
                var aacWithADTS = Data()
                aacWithADTS.append(adtsHeader)
                aacWithADTS.append(aacRawData)
                
                return aacWithADTS
            }
            
            return nil
        }
    }
    
    /// 创建ADTS头（7字节）
    /// ADTS头格式说明：
    /// - 用于AAC裸流传输，使播放器能够识别和解码AAC数据
    /// - 每一帧AAC数据前都需要添加7字节的ADTS头
    private func createADTSHeader(dataLength: Int) -> Data {
        let packetLength = dataLength + 7  // AAC数据长度 + ADTS头长度(7字节)
        
        var adtsHeader = [UInt8](repeating: 0, count: 7)
        
        // 配置参数
        let profile: UInt8 = 2  // AAC-LC (profile = 2, 编码时使用 profile - 1 = 1)
        let freqIndex: UInt8 = 8  // 16000 Hz 对应索引 8
        let channelConfig: UInt8 = UInt8(channels)  // 1 = 单声道
        
        // Byte 0: Syncword (12 bits) 高8位
        adtsHeader[0] = 0xFF
        
        // Byte 1: Syncword (12 bits) 低4位 + ID (1 bit) + Layer (2 bits) + protection_absent (1 bit)
        // 0xF (syncword低4位) + 0 (MPEG-4) + 00 (Layer) + 1 (no CRC)
        adtsHeader[1] = 0xF1
        
        // Byte 2: Profile (2 bits) + Sampling frequency index (4 bits) + Private bit (1 bit) + Channel config 高1位
        // Profile: AAC-LC = 1 (profile - 1)
        // Freq index: 8 (16000 Hz)
        // Private: 0
        // Channel config 高1位: 0 (单声道的最高位)
        adtsHeader[2] = ((profile - 1) << 6) | (freqIndex << 2) | (channelConfig >> 2)
        
        // Byte 3: Channel config 低2位 + Original/Copy (1 bit) + Home (1 bit) + Copyrighted ID (1 bit) + Copyrighted ID start (1 bit) + Frame length 高2位
        adtsHeader[3] = ((channelConfig & 0x3) << 6) | UInt8((packetLength >> 11) & 0x3)
        
        // Byte 4: Frame length 中间8位
        adtsHeader[4] = UInt8((packetLength >> 3) & 0xFF)
        
        // Byte 5: Frame length 低3位 + Buffer fullness 高5位
        // Buffer fullness = 0x7FF (VBR)
        adtsHeader[5] = UInt8(((packetLength & 0x7) << 5) | 0x1F)
        
        // Byte 6: Buffer fullness 低6位 + Number of frames (2 bits)
        // Buffer fullness低6位 = 0x3F, Number of frames = 0 (表示1帧)
        adtsHeader[6] = 0xFC
        
        return Data(adtsHeader)
    }
    
    private func releaseEncoder(result: @escaping FlutterResult) {
        if let converter = audioConverter {
            AudioConverterDispose(converter)
            audioConverter = nil
            pcmBuffer.removeAll()
        }
        result(true)
    }
}

// MARK: - FlutterStreamHandler
extension AACEncoderPlugin: FlutterStreamHandler {
    public func onListen(withArguments arguments: Any?, eventSink events: @escaping FlutterEventSink) -> FlutterError? {
        self.eventSink = events
        return nil
    }
    
    public func onCancel(withArguments arguments: Any?) -> FlutterError? {
        self.eventSink = nil
        return nil
    }
}

// MARK: - Helper Structures
private struct AudioBufferContext {
    var dataPtr: UnsafeMutableRawPointer
    var dataSize: Int
    var channels: UInt32
    var dataProvided: Bool
}
