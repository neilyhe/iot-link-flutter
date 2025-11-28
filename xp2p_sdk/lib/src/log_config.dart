class LogConfig {
  bool p2pLogEnabled;

  bool opsLogEnabled;

  String p2pLogLevel;

  LogConfig({
    this.p2pLogEnabled = false,
    this.opsLogEnabled = true,
    this.p2pLogLevel = '',
  });

  @override
  String toString() {
    return 'LogConfig(p2pLogEnabled: $p2pLogEnabled, opsLogEnabled: $opsLogEnabled, p2pLogLevel: $p2pLogLevel)';
  }
}
