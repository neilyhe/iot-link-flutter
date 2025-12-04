package com.tencent.encoder

import android.media.MediaCodec
import android.media.MediaCodecInfo
import android.media.MediaCodecList
import android.media.MediaFormat
import android.os.Build
import android.util.Log

/**
 * Android H.264视频编码器
 * 使用MediaCodec硬件编码器
 */
class VideoEncoder {
    companion object {
        private const val TAG = "VideoCapture"
        private const val IFRAME_INTERVAL = 21 // I帧间隔（秒）
        private const val TIMEOUT_USEC = 10000L // 10ms超时
        private const val MAX_BITRATE_LENGTH = 1000000
    }

    private var mediaCodec: MediaCodec? = null
    private var width: Int = 0
    private var height: Int = 0
    private var isInitialized = false
    private var firstSupportColorFormatCodecName =
        "" //  OMX.qcom.video.encoder.avc 和 c2.android.avc.encoder 过滤，这两个h264编码性能好一些。如果都不支持COLOR_FormatYUV420Planar，就用默认的方式。
    private var isSupportNV21 = false

    /**
     * 初始化编码器
     */
    fun initialize(width: Int, height: Int, fps: Int, bitrate: Int): Boolean {
        try {
            if (isInitialized) {
                Log.w(TAG, "编码器已初始化")
                return true
            }

            this.width = width
            this.height = height
            Log.i(TAG, "初始化编码器: ${width}x${height}, fps=$fps, bitrate=$bitrate")
            checkSupportedColorFormats()

            mediaCodec = if (!firstSupportColorFormatCodecName.isEmpty()) {
                MediaCodec.createByCodecName(firstSupportColorFormatCodecName)
            } else {
                MediaCodec.createEncoderByType("video/avc")
            }

            //height和width一般都是照相机的height和width。
            val mediaFormat =
                MediaFormat.createVideoFormat(MediaFormat.MIMETYPE_VIDEO_AVC, height, width)
            //描述平均位速率（以位/秒为单位）的键。 关联的值是一个整数
            mediaFormat.setInteger(MediaFormat.KEY_BIT_RATE, if (bitrate > MAX_BITRATE_LENGTH) MAX_BITRATE_LENGTH else bitrate)
            //描述视频格式的帧速率（以帧/秒为单位）的键。帧率，一般在15至30之内，太小容易造成视频卡顿。
            mediaFormat.setInteger(MediaFormat.KEY_FRAME_RATE, fps)
            if (isSupportNV21) {
                //色彩格式，具体查看相关API，不同设备支持的色彩格式不尽相同
                mediaFormat.setInteger(MediaFormat.KEY_COLOR_FORMAT, MediaCodecInfo.CodecCapabilities.COLOR_FormatYUV420SemiPlanar)
            } else {
                //色彩格式，具体查看相关API，不同设备支持的色彩格式不尽相同
                mediaFormat.setInteger(MediaFormat.KEY_COLOR_FORMAT, MediaCodecInfo.CodecCapabilities.COLOR_FormatYUV420Planar)
            }

            //关键帧间隔时间，单位是秒
            mediaFormat.setInteger(MediaFormat.KEY_I_FRAME_INTERVAL, IFRAME_INTERVAL) // I帧间隔: 默认一秒一个 I 帧
            mediaFormat.setInteger(MediaFormat.KEY_BITRATE_MODE, MediaCodecInfo.EncoderCapabilities.BITRATE_MODE_VBR)
            //设置压缩等级  默认是 baseline
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
                mediaFormat.setInteger(MediaFormat.KEY_LEVEL, MediaCodecInfo.CodecProfileLevel.AVCLevel3)
            } else if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.LOLLIPOP) {
                mediaFormat.setInteger(MediaFormat.KEY_PROFILE, MediaCodecInfo.CodecProfileLevel.AVCProfileMain)
            }
            mediaCodec?.configure(mediaFormat, null, null, MediaCodec.CONFIGURE_FLAG_ENCODE)
            mediaCodec?.start()
            isInitialized = true
            Log.i(TAG, "编码器初始化成功")
            return true
        } catch (e: Exception) {
            Log.e(TAG, "初始化编码器失败", e)
            release()
            return false
        }
    }

    private fun checkSupportedColorFormats() {
        MediaCodecList(MediaCodecList.ALL_CODECS).codecInfos.forEach { codecInfo ->
            if (codecInfo.isEncoder && (codecInfo.name == "OMX.qcom.video.encoder.avc" || codecInfo.name == "c2.android.avc.encoder")) {
                codecInfo.supportedTypes.forEachIndexed { _, type ->
                    if (type.startsWith("video/")) {
                        val capabilities = codecInfo.getCapabilitiesForType(type)
                        capabilities.colorFormats.forEachIndexed { _, colorFormat ->
                            when (colorFormat) {
                                MediaCodecInfo.CodecCapabilities.COLOR_FormatYUV420Planar -> {
                                    Log.e(TAG, "Supported color format: COLOR_FormatYUV420Planar")
                                    firstSupportColorFormatCodecName = codecInfo.name
                                    isSupportNV21 = false
                                    return
                                }

                                MediaCodecInfo.CodecCapabilities.COLOR_FormatYUV420SemiPlanar -> {
                                    Log.e(
                                        TAG, "Supported color format: COLOR_FormatYUV420SemiPlanar"
                                    )
                                    isSupportNV21 = true
                                    return
                                }

                                else -> Log.e(TAG, "Supported color format: " + colorFormat)
                            }
                        }
                    }
                }
            }
        }
    }

    /**
     * 编码单帧YUV420数据
     */
    fun encodeFrame(data: ByteArray, mirror: Boolean): ByteArray? {
        if (!isInitialized || mediaCodec == null) {
            Log.w(TAG, "编码器未初始化")
            return null
        }
        var readyToProcessBytes: ByteArray = data
//        if (isSupportNV21) {
//            //将NV21编码成NV12
//            val bytes: ByteArray = NV21ToNV12(data, width, height)
//            //视频顺时针旋转90度
//            val nv12: ByteArray = rotateNV290(bytes, width, height)
//
//            if (mirror) {
//                verticalMirror(nv12, height, width)
//            }
//            readyToProcessBytes = nv12
//        } else {
//            val rotateBytes: ByteArray
//            //视频顺时针旋转90度
//            if (mirror) {
//                rotateBytes = nv21Rotate270(data, width, height)
//            } else {
//                rotateBytes = nv21Rotate90(data, width, height)
//            }
//            //将NV21编码成I420
//            val i420: ByteArray = toI420(rotateBytes, height, width)
//            readyToProcessBytes = i420
//        }

        try {
            val inputBufferIndex = mediaCodec!!.dequeueInputBuffer(TIMEOUT_USEC)
            if (inputBufferIndex >= 0) {
                val inputBuffer = mediaCodec!!.getInputBuffer(inputBufferIndex)
                inputBuffer?.clear()
                inputBuffer?.put(readyToProcessBytes)

                val presentationTimeUs = System.nanoTime() / 1000
                mediaCodec!!.queueInputBuffer(inputBufferIndex, 0, readyToProcessBytes.size, presentationTimeUs, 0)
            } else {
                Log.w(TAG, "无可用输入缓冲区")
            }

            val bufferInfo = MediaCodec.BufferInfo()
            val outputBufferIndex = mediaCodec!!.dequeueOutputBuffer(bufferInfo, TIMEOUT_USEC)

            if (outputBufferIndex >= 0) {
                val outputBuffer = mediaCodec!!.getOutputBuffer(outputBufferIndex)

                if (outputBuffer != null && bufferInfo.size > 0) {
                    val h264Data = ByteArray(bufferInfo.size)
                    outputBuffer.position(bufferInfo.offset)
                    outputBuffer.limit(bufferInfo.offset + bufferInfo.size)
                    outputBuffer.get(h264Data)
                    mediaCodec?.releaseOutputBuffer(outputBufferIndex, false)
                    return h264Data
                }

                mediaCodec!!.releaseOutputBuffer(outputBufferIndex, false)
            } else if (outputBufferIndex == MediaCodec.INFO_OUTPUT_FORMAT_CHANGED) {
                val newFormat = mediaCodec!!.outputFormat
                Log.i(TAG, "输出格式变化: $newFormat")
            } else if (outputBufferIndex == MediaCodec.INFO_TRY_AGAIN_LATER) {
                Log.d(TAG, "暂无输出数据")
            }

            return null
        } catch (e: Exception) {
            Log.e(TAG, "编码帧失败", e)
            return null
        }
    }

    /**
     * 释放编码器资源
     */
    fun release() {
        try {
            mediaCodec?.stop()
            mediaCodec?.release()
            mediaCodec = null
            isInitialized = false
            width = 0
            height = 0
            firstSupportColorFormatCodecName = ""
            isSupportNV21 = false
            Log.i(TAG, "编码器已释放")
        } catch (e: Exception) {
            Log.e(TAG, "释放编码器失败", e)
        }
    }

    /**
     * 因为从MediaCodec不支持NV21的数据编码，所以需要先讲NV21的数据转码为NV12
     */
    var nv12: ByteArray? = null

    private fun NV21ToNV12(nv21: ByteArray, width: Int, height: Int): ByteArray {
        if (nv12 == null) {
            nv12 = ByteArray(width * height * 3 / 2)
        }
        val frameSize = width * height
        var i: Int
        var j: Int
        System.arraycopy(nv21, 0, nv12!!, 0, frameSize)
        i = 0
        while (i < frameSize) {
            nv12!![i] = nv21[i]
            i++
        }
        j = 0
        while (j < frameSize / 2) {
            nv12!![frameSize + j - 1] = nv21[j + frameSize]
            j += 2
        }
        j = 0
        while (j < frameSize / 2) {
            nv12!![frameSize + j] = nv21[j + frameSize - 1]
            j += 2
        }
        return nv12!!
    }

    var preAllocatedBufferColor420: ByteArray? = null
    fun toI420(input: ByteArray, width: Int, height: Int): ByteArray {
        if (preAllocatedBufferColor420 == null) {
            preAllocatedBufferColor420 = ByteArray(width * height * 3 / 2)
        }
        val frameSize = width * height
        val qFrameSize = frameSize / 4
        System.arraycopy(input, 0, preAllocatedBufferColor420!!, 0, frameSize) // Y
        for (i in 0..<qFrameSize) {
            preAllocatedBufferColor420!![frameSize + i] = input[frameSize + i * 2 + 1] // Cb (U)
            preAllocatedBufferColor420!![frameSize + i + qFrameSize] =
                input[frameSize + i * 2] // Cr (V)
        }
        return preAllocatedBufferColor420!!
    }

    var preAllocatedBufferRotate90: ByteArray? = null
    fun nv21Rotate90(data: ByteArray, imageWidth: Int, imageHeight: Int): ByteArray {
        if (preAllocatedBufferRotate90 == null) {
            preAllocatedBufferRotate90 = ByteArray(imageWidth * imageHeight * 3 / 2)
        }
        // Rotate the Y luma
        var i = 0
        for (x in 0..<imageWidth) {
            for (y in imageHeight - 1 downTo 0) {
                preAllocatedBufferRotate90!![i++] = data[y * imageWidth + x]
            }
        }
        // Rotate the U and V color components
        val size = imageWidth * imageHeight
        i = size * 3 / 2 - 1
        var x = imageWidth - 1
        while (x > 0) {
            for (y in 0..<imageHeight / 2) {
                preAllocatedBufferRotate90!![i--] = data[size + (y * imageWidth) + x]
                preAllocatedBufferRotate90!![i--] = data[size + (y * imageWidth) + (x - 1)]
            }
            x = x - 2
        }
        return preAllocatedBufferRotate90!!
    }

    var preAllocatedBufferRotate270: ByteArray? = null
    fun nv21Rotate270(data: ByteArray, imageWidth: Int, imageHeight: Int): ByteArray {
        if (preAllocatedBufferRotate270 == null) {
            preAllocatedBufferRotate270 = ByteArray(imageWidth * imageHeight * 3 / 2)
        }
        // Rotate the Y luma
        var i = 0
        for (x in imageWidth - 1 downTo 0) {
            for (y in 0..<imageHeight) {
                preAllocatedBufferRotate270!![i++] = data[y * imageWidth + x]
            }
        }

        // Rotate the U and V color components
        i = imageWidth * imageHeight
        val uvHeight = imageHeight / 2
        var x = imageWidth - 1
        while (x >= 0) {
            for (y in imageHeight..<uvHeight + imageHeight) {
                preAllocatedBufferRotate270!![i++] = data[y * imageWidth + x - 1]
                preAllocatedBufferRotate270!![i++] = data[y * imageWidth + x]
            }
            x -= 2
        }
        return preAllocatedBufferRotate270!!
    }

    /**
     * 此处为顺时针旋转旋转90度
     *
     * @param data        旋转前的数据
     * @param imageWidth  旋转前数据的宽
     * @param imageHeight 旋转前数据的高
     * @return 旋转后的数据
     */
    var yuv290: ByteArray? = null
    private fun rotateNV290(data: ByteArray, imageWidth: Int, imageHeight: Int): ByteArray {
        if (yuv290 == null) {
            yuv290 = ByteArray(imageWidth * imageHeight * 3 / 2)
        }
        // Rotate the Y luma
        var i = 0
        for (x in 0..<imageWidth) {
            for (y in imageHeight - 1 downTo 0) {
                yuv290!![i] = data[y * imageWidth + x]
                i++
            }
        }
        // Rotate the U and V color components
        i = imageWidth * imageHeight * 3 / 2 - 1
        var x = imageWidth - 1
        while (x > 0) {
            for (y in 0..<imageHeight / 2) {
                yuv290!![i] = data[(imageWidth * imageHeight) + (y * imageWidth) + x]
                i--
                yuv290!![i] = data[(imageWidth * imageHeight) + (y * imageWidth) + (x - 1)]
                i--
            }
            x = x - 2
        }
        return yuv290!!
    }

    private fun verticalMirror(src: ByteArray, w: Int, h: Int) { //src是原始yuv数组
        var i: Int
        val index: Int
        var temp: Byte
        var a: Int
        var b: Int
        //mirror y
        i = 0
        while (i < w) {
            a = i
            b = (h - 1) * w + i
            while (a < b) {
                temp = src[a]
                src[a] = src[b]
                src[b] = temp
                a += w
                b -= w
            }
            i++
        }

        // mirror u and v
        index = w * h
        i = 0
        while (i < w) {
            a = i
            b = (h / 2 - 1) * w + i
            while (a < b) {
                temp = src[a + index]
                src[a + index] = src[b + index]
                src[b + index] = temp
                a += w
                b -= w
            }
            i++
        }
    }
}