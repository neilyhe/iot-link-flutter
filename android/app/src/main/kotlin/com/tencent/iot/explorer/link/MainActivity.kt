package com.tencent.iot.explorer.link

import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import com.tencent.encoder.VideoEncoder

class MainActivity : FlutterActivity() {
    private val CHANNEL = "video_encoder"
    private var encoder: VideoEncoder? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            CHANNEL
        ).setMethodCallHandler { call, result ->
            when (call.method) {
                "initialize" -> {
                    val width = call.argument<Int>("width") ?: 0
                    val height = call.argument<Int>("height") ?: 0
                    val fps = call.argument<Int>("fps") ?: 30
                    val bitrate = call.argument<Int>("bitrate") ?: 1000000

                    encoder = VideoEncoder()
                    val success = encoder?.initialize(width, height, fps, bitrate) ?: false
                    result.success(success)
                }

                "encodeFrame" -> {
                    val data = call.argument<ByteArray>("yuvData")
                    val mirror = call.argument<Boolean>("mirror") ?: false
                    if (data != null && encoder != null) {
                        val h264Data = encoder?.encodeFrame(data, mirror)
                        result.success(h264Data)
                    } else {
                        result.error("NO_DATA", "YUV数据为空或编码器未初始化", null)
                    }
                }

                "release" -> {
                    encoder?.release()
                    encoder = null
                    result.success(null)
                }

                else -> result.notImplemented()
            }
        }
    }
}
