package com.tencent.encoder

import android.media.MediaCodec
import android.media.MediaCodecInfo
import android.media.MediaFormat
import android.os.Build
import android.util.Log
import java.nio.ByteBuffer

/**
 * Android AAC音频编码器
 * 使用MediaCodec硬件编码器将PCM音频数据转换为AAC格式
 */
class AudioEncoder {
    companion object {
        private const val TAG = "AudioEncoder"
        private const val MIME_TYPE = "audio/mp4a-latm" // AAC格式
        private const val TIMEOUT_USEC = 10000L // 10ms超时
        
        // 默认音频参数
        private const val DEFAULT_SAMPLE_RATE = 16000 // 16kHz
        private const val DEFAULT_CHANNEL_COUNT = 1 // 单声道
        private const val DEFAULT_BIT_RATE = 32000 // 64kbps
    }

    private var audioCodec: MediaCodec? = null
    private var isInitialized = false
    private var sampleRate: Int = DEFAULT_SAMPLE_RATE
    private var channelCount: Int = DEFAULT_CHANNEL_COUNT
    private var bitRate: Int = DEFAULT_BIT_RATE
    
    // 缓冲区，用于累积PCM数据
    private val pcmBuffer = mutableListOf<Byte>()
    private var frameSize: Int = 0 // 每帧需要的PCM数据大小

    /**
     * 采样频率对照表
     */
    private val samplingFrequencyIndexMap = mapOf(
        96000 to 0,
        88200 to 1,
        64000 to 2,
        48000 to 3,
        44100 to 4,
        32000 to 5,
        24000 to 6,
        22050 to 7,
        16000 to 8,
        12000 to 9,
        11025 to 10,
        8000 to 11
    )

    /**
     * 初始化编码器
     * 
     * @param sampleRate 采样率（Hz），默认16000
     * @param channelCount 声道数，默认1（单声道）
     * @param bitRate 比特率（bps），默认64000
     * @return 是否初始化成功
     */
    fun initialize(
        sampleRate: Int = DEFAULT_SAMPLE_RATE,
        channelCount: Int = DEFAULT_CHANNEL_COUNT,
        bitRate: Int = DEFAULT_BIT_RATE
    ): Boolean {
        try {
            if (isInitialized) {
                Log.w(TAG, "编码器已初始化")
                return true
            }

            this.sampleRate = sampleRate
            this.channelCount = channelCount
            this.bitRate = bitRate

            Log.i(TAG, "初始化AAC编码器: sampleRate=$sampleRate, channels=$channelCount, bitRate=$bitRate")

            // 创建AAC编码器
            audioCodec = MediaCodec.createEncoderByType(MIME_TYPE)

            // 配置编码器参数
            val mediaFormat = MediaFormat.createAudioFormat(MIME_TYPE, sampleRate, channelCount)
            mediaFormat.setInteger(MediaFormat.KEY_AAC_PROFILE, MediaCodecInfo.CodecProfileLevel.AACObjectLC)
            mediaFormat.setInteger(MediaFormat.KEY_BIT_RATE, bitRate)
            mediaFormat.setInteger(MediaFormat.KEY_MAX_INPUT_SIZE, 16384)

            audioCodec?.configure(mediaFormat, null, null, MediaCodec.CONFIGURE_FLAG_ENCODE)
            audioCodec?.start()

            // 计算每帧大小（AAC编码器通常需要1024个样本）
            frameSize = 1024 * channelCount * 2 // 16位 = 2字节

            isInitialized = true
            Log.i(TAG, "AAC编码器初始化成功，每帧大小: $frameSize 字节")
            return true
        } catch (e: Exception) {
            Log.e(TAG, "初始化AAC编码器失败", e)
            release()
            return false
        }
    }

    /**
     * 编码PCM数据为AAC
     * 
     * @param pcmData PCM 16bit 音频数据
     * @return AAC编码后的数据，如果缓冲区数据不足一帧则返回null
     */
    fun encodePCM(pcmData: ByteArray): ByteArray? {
        if (!isInitialized || audioCodec == null) {
            Log.w(TAG, "编码器未初始化")
            return null
        }

        try {
            pcmBuffer.addAll(pcmData.toList())
            if (pcmBuffer.size < frameSize) {
                return null
            }

            // 取出一帧数据
            val frameData = ByteArray(frameSize)
            for (i in 0 until frameSize) {
                frameData[i] = pcmBuffer.removeAt(0)
            }
            // 将PCM数据送入编码器输入缓冲区
            val inputBufferIndex = audioCodec!!.dequeueInputBuffer(TIMEOUT_USEC)
            if (inputBufferIndex >= 0) {
                val inputBuffer: ByteBuffer?
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.LOLLIPOP) {
                    inputBuffer = audioCodec!!.getInputBuffer(inputBufferIndex)
                } else {
                    inputBuffer = audioCodec!!.getInputBuffers()[inputBufferIndex]
                }
                
                if (inputBuffer != null) {
                    inputBuffer.clear()
                    inputBuffer.put(frameData)
                    audioCodec!!.queueInputBuffer(
                        inputBufferIndex,
                        0,
                        frameData.size,
                        System.nanoTime() / 1000,
                        0
                    )
                }
            }

            // 获取编码后的AAC数据
            val bufferInfo = MediaCodec.BufferInfo()
            var outputBufferIndex = audioCodec!!.dequeueOutputBuffer(bufferInfo, TIMEOUT_USEC)
            var aacResult: ByteArray? = null
            // 循环处理所有可用的输出缓冲区
            while (outputBufferIndex >= 0 || outputBufferIndex == MediaCodec.INFO_OUTPUT_FORMAT_CHANGED) {
                when (outputBufferIndex) {
                    MediaCodec.INFO_OUTPUT_FORMAT_CHANGED -> {
                        // 输出格式变化，这是正常的，继续获取下一个输出
                        val newFormat = audioCodec!!.outputFormat
                        Log.i(TAG, "编码器输出格式变化: $newFormat")
                    }
                    MediaCodec.INFO_TRY_AGAIN_LATER -> {
                        // 暂时没有可用输出，退出循环
                        Log.d(TAG, "暂时没有可用的输出缓冲区")
                        break
                    }
                    else -> {
                        if (outputBufferIndex >= 0) {
                            val outputBuffer: ByteBuffer?
                            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.LOLLIPOP) {
                                outputBuffer = audioCodec!!.getOutputBuffer(outputBufferIndex)
                            } else {
                                outputBuffer = audioCodec!!.getOutputBuffers()[outputBufferIndex]
                            }

                            if (outputBuffer != null && bufferInfo.size > 0) {
                                outputBuffer.position(bufferInfo.offset)
                                outputBuffer.limit(bufferInfo.offset + bufferInfo.size)
                                val aacDataWithADTS = addADTStoPacket(outputBuffer)
                                // 保存第一个有效的AAC数据
                                if (aacResult == null) {
                                    aacResult = aacDataWithADTS
                                }
                            }
                            // 必须释放输出缓冲区，否则会导致缓冲区耗尽
                            audioCodec!!.releaseOutputBuffer(outputBufferIndex, false)
                        }
                    }
                }
                // 继续获取下一个输出缓冲区（使用0超时，不阻塞）
                outputBufferIndex = audioCodec!!.dequeueOutputBuffer(bufferInfo, 0)
            }
            return aacResult

        } catch (e: Exception) {
            Log.e(TAG, "编码PCM数据失败", e)
            return null
        }
    }

    private fun addADTStoPacket(outputBuffer: ByteBuffer): ByteArray {
        val bytes = ByteArray(outputBuffer.remaining())
        outputBuffer.get(bytes, 0, bytes.size)
        val dataBytes = ByteArray(bytes.size + 7)
        System.arraycopy(bytes, 0, dataBytes, 7, bytes.size)
        addADTStoPacket(dataBytes, dataBytes.size)
        return dataBytes
    }

    private fun addADTStoPacket(packet: ByteArray, packetLen: Int) {
        // AAC LC
        val profile = 2
        // CPE
        val chanCfg = 1
        val freqIdx: Int = samplingFrequencyIndexMap.get(sampleRate) ?: 8
        // filled in ADTS data
        packet[0] = 0xFF.toByte()
        packet[1] = 0xF9.toByte()
        packet[2] = (((profile - 1) shl 6) + (freqIdx shl 2) + (chanCfg shr 2)).toByte()
        packet[3] = (((chanCfg and 3) shl 6) + (packetLen shr 11)).toByte()
        packet[4] = ((packetLen and 0x7FF) shr 3).toByte()
        packet[5] = (((packetLen and 7) shl 5) + 0x1F).toByte()
        packet[6] = 0xFC.toByte()
    }

    /**
     * 释放编码器资源
     */
    fun release() {
        try {
            audioCodec?.stop()
            audioCodec?.release()
            audioCodec = null
            isInitialized = false
            pcmBuffer.clear()
            Log.i(TAG, "AAC编码器已释放")
        } catch (e: Exception) {
            Log.e(TAG, "释放AAC编码器失败", e)
        }
    }

    /**
     * 检查是否已初始化
     */
    fun isInitialized(): Boolean = isInitialized
}