enum LogLevel {
  debug,
  info,
  warn,
  error,
}

/// 日志工具类
class Logger {
  static LogLevel _currentLevel = LogLevel.debug;
  static bool _enableConsoleOutput = true;
  static Function(String)? _uiLogCallback;

  /// 设置日志级别
  static void setLevel(LogLevel level) {
    _currentLevel = level;
  }

  /// 启用/禁用控制台输出
  static void setConsoleOutput(bool enable) {
    _enableConsoleOutput = enable;
  }

  /// 设置UI日志回调
  static void setUiLogCallback(Function(String) callback) {
    _uiLogCallback = callback;
  }

  static bool _shouldLog(LogLevel level) {
    return level.index >= _currentLevel.index;
  }

  static String _getLevelName(LogLevel level) {
    switch (level) {
      case LogLevel.debug:
        return 'DEBUG';
      case LogLevel.info:
        return 'INFO';
      case LogLevel.warn:
        return 'WARN';
      case LogLevel.error:
        return 'ERROR';
    }
  }

  static String _formatMessage(LogLevel level, String message, [String? tag]) {
    final timestamp = DateTime.now().toString().substring(11, 19);
    final levelName = _getLevelName(level);
    final tagPart = tag != null ? ' [$tag]' : '';
    return '[$timestamp] [$levelName]$tagPart: $message';
  }

  static void _log(LogLevel level, String message, [String? tag]) {
    if (!_shouldLog(level)) return;
    final formattedMessage = _formatMessage(level, message, tag);
    if (_enableConsoleOutput) {
      print(formattedMessage);
    }
    _uiLogCallback?.call(formattedMessage);
  }

  static void d(String message, [String? tag]) {
    _log(LogLevel.debug, message, tag);
  }

  static void i(String message, [String? tag]) {
    _log(LogLevel.info, message, tag);
  }

  static void w(String message, [String? tag]) {
    _log(LogLevel.warn, message, tag);
  }

  static void e(String message, [String? tag]) {
    _log(LogLevel.error, message, tag);
  }

  static void eWithException(String message, dynamic error, [String? tag]) {
    final fullMessage = '$message: $error';
    _log(LogLevel.error, fullMessage, tag);
  }
}