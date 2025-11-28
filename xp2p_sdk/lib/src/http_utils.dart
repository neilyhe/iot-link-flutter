import 'dart:convert';
import 'dart:typed_data';
import 'package:http/http.dart' as http;
import 'package:xp2p_sdk/src/log/logger.dart';

/// HTTP 响应监听器
typedef OnResponseListener = void Function(
  String requestId,
  int responseCode,
  String msg,
  String content,
);

/// HTTP 工具类
///
/// 用于发送 HTTP POST 请求
class HttpUtils {

  factory HttpUtils() => _instance;

  HttpUtils._internal();
  static final HttpUtils _instance = HttpUtils._internal();

  static HttpUtils get instance => _instance;

  /// 发送 POST 请求
  Future<void> basePost(
    String url,
    Uint8List data,
    String requestId,
    OnResponseListener listener,
  ) async {
    return basePostWithRange(url, data, 0, data.length, requestId, listener);
  }

  /// 发送 POST 请求
  Future<void> basePostWithRange(
    String url,
    Uint8List data,
    int off,
    int len,
    String requestId,
    OnResponseListener listener,
  ) async {
    try {
      final uri = Uri.parse(url);
      final request = http.Request('POST', uri);
      request.headers['Content-Type'] = 'application/json';
      request.bodyBytes = data.sublist(off, off + len);
      final streamedResponse = await request.send();
      final response = await http.Response.fromStream(streamedResponse);
      final responseCode = response.statusCode;
      final responseContent = response.statusCode == 200 ? response.body : '';

      listener(
        requestId,
        responseCode,
        response.reasonPhrase ?? '',
        responseContent,
      );
    } catch (e) {
      Logger.e('HTTP request error: $e',"XP2P");
      listener(requestId, 500, 'Error: $e', '');
    }
  }
}
