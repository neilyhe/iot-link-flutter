/// XP2P SDK for Flutter
///
/// 腾讯物联网 XP2P SDK，提供 P2P 连接功能,支持视频直播、回放、语音对讲等功能。
library xp2p_sdk;

export 'src/xp2p.dart';
export 'src/xp2p_callback.dart';
export 'src/xp2p_app_config.dart';
export 'src/xp2p_types.dart';
export 'src/xp2p_error_code.dart';
export 'src/config_util.dart';
export 'src/log_config.dart';
export 'src/command.dart';
export 'src/log/logger.dart';
export 'src/media/tx_live_player.dart';
export 'src/utils/string_ext.dart';
export 'src/utils/file_utils.dart';
export 'src/media_server/flv_packer.dart';
export 'src/soundtouch/sound_touch.dart';

/// trtc sdk live player
// export 'package:tencent_rtc_sdk/v2_tx_live_player_observer.dart';
// export 'package:tencent_rtc_sdk/v2_tx_live_code.dart';
// export 'package:tencent_rtc_sdk/trtc_cloud_video_view.dart';

/// live sdk player
export 'package:live_flutter_plugin/v2_tx_live_player_observer.dart';
export 'package:live_flutter_plugin/v2_tx_live_code.dart';
export 'package:live_flutter_plugin/widget/v2_tx_live_video_widget.dart';
