package com.tencent.iot.explorer.link

import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import com.tencent.encoder.VideoEncoder
import com.tencent.encoder.AudioEncoder

class MainActivity : FlutterActivity() {
    private val VIDEO_CHANNEL = "h264_encoder"
    private val AUDIO_CHANNEL = "aac_encoder"
    private var videoEncoder: VideoEncoder? = null
    private var audioEncoder: AudioEncoder? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        // 视频编码器通道
        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            VIDEO_CHANNEL
        ).setMethodCallHandler { call, result ->
            when (call.method) {
                "initialize" -> {
                    val width = call.argument<Int>("width") ?: 0
                    val height = call.argument<Int>("height") ?: 0
                    val fps = call.argument<Int>("fps") ?: 30
                    val bitrate = call.argument<Int>("bitrate") ?: 1000000

                    videoEncoder = VideoEncoder()
                    val success = videoEncoder?.initialize(width, height, fps, bitrate) ?: false
                    result.success(success)
                }

                "encodeFrame" -> {
                    val data = call.argument<ByteArray>("yuvData")
                    val mirror = call.argument<Boolean>("mirror") ?: false
                    if (data != null && videoEncoder != null) {
                        val h264Data = videoEncoder?.encodeFrame(data, mirror)
                        result.success(h264Data)
                    } else {
                        result.error("NO_DATA", "YUV数据为空或编码器未初始化", null)
                    }
                }

                "release" -> {
                    videoEncoder?.release()
                    videoEncoder = null
                    result.success(null)
                }

                else -> result.notImplemented()
            }
        }

        // AAC音频编码器通道
        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            AUDIO_CHANNEL
        ).setMethodCallHandler { call, result ->
            when (call.method) {
                "initEncoder" -> {
                    val sampleRate = call.argument<Int>("sampleRate") ?: 16000
                    val channelCount = call.argument<Int>("channelCount") ?: 1
                    val bitRate = call.argument<Int>("bitRate") ?: 32000

                    audioEncoder = AudioEncoder()
                    val success = audioEncoder?.initialize(sampleRate, channelCount, bitRate) ?: false
                    
                    result.success(success)
                }

                "encodePCM" -> {
                    val pcmData = call.argument<ByteArray>("pcmData")
                    if (pcmData != null && audioEncoder != null) {
                        val aacData = audioEncoder?.encodePCM(pcmData)
                        result.success(aacData)
                    } else {
                        result.error("NO_DATA", "PCM数据为空或编码器未初始化", null)
                    }
                }

                "releaseEncoder" -> {
                    audioEncoder?.release()
                    audioEncoder = null
                    result.success(null)
                }

                else -> result.notImplemented()
            }
        }
    }
}
