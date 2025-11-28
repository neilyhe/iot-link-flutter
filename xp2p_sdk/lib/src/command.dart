
// 信令
class Command {
  Command._();

  // 查询 NVR 设备列表
  static const String queryNvrDevs = 'action=inner_define&cmd=get_nvr_list';

  static String getCustomCommand(int channel, String cmd) {
    return 'action=user_define&channel=$channel&cmd=$cmd';
  }

  static String getPtzUpCommand(int channel) {
    return 'action=user_define&channel=$channel&cmd=ptz_up';
  }

  static String getPtzDownCommand(int channel) {
    return 'action=user_define&channel=$channel&cmd=ptz_down';
  }

  static String getPtzRightCommand(int channel) {
    return 'action=user_define&channel=$channel&cmd=ptz_right';
  }

  static String getPtzLeftCommand(int channel) {
    return 'action=user_define&channel=$channel&cmd=ptz_left';
  }

  static String getVideoStandardQualityUrlSuffix(int channel) {
    return 'ipc.flv?action=live&channel=$channel&quality=standard';
  }

  static String getVideoHightQualityUrlSuffix(int channel) {
    return 'ipc.flv?action=live&channel=$channel&quality=high';
  }

  static String getVideoSuperQualityUrlSuffix(int channel) {
    return 'ipc.flv?action=live&channel=$channel&quality=super';
  }

  static String getVideoMJPEGUrlSuffix(int channel) {
    return 'ipc.flv?action=live-mjpg&channel=$channel&quality=standard';
  }

  static String getVideoMJPEGAACUrlSuffix() {
    return 'ipc.flv?action=live-audio';
  }

  static String getNvrIpcStatus(int channel, int type) {
    String typeStr = 'live';
    switch (type) {
      case 0:
        typeStr = 'live';
        break;
      case 1:
        typeStr = 'voice';
        break;
      default:
        typeStr = 'live';
        break;
    }
    return 'action=inner_define&channel=$channel&cmd=get_device_st&type=$typeStr&quality=standard';
  }

  static String getTwoWayRadio(int channel) {
    return 'channel=$channel';
  }

  /// time: yyyymm 年月
  static String getMonthDates(int channel, String time) {
    return 'action=inner_define&channel=$channel&cmd=get_month_record&time=$time';
  }

  static String getDayTimeBlocks(int channel, DateTime date) {
    final dateStart = DateTime(date.year, date.month, date.day, 0, 0, 0);
    final dateEnd = DateTime(date.year, date.month, date.day, 23, 59, 59);

    final startSeconds = dateStart.millisecondsSinceEpoch ~/ 1000;
    final endSeconds = dateEnd.millisecondsSinceEpoch ~/ 1000;

    return 'action=inner_define&channel=$channel&cmd=get_file_list'
        '&start_time=$startSeconds&end_time=$endSeconds&file_type=0';
  }

  static String getLocalVideoUrl(int channel, int startTime, int endTime) {
    return 'ipc.flv?action=playback&channel=$channel&start_time=$startTime&end_time=$endTime';
  }

  static String pauseLocalVideoUrl(int channel) {
    return 'action=inner_define&channel=$channel&cmd=playback_pause';
  }

  static String resumeLocalVideoUrl(int channel) {
    return 'action=inner_define&channel=$channel&cmd=playback_resume';
  }

  static String seekLocalVideo(int channel, int offset) {
    return 'action=inner_define&channel=$channel&cmd=playback_seek&time=$offset';
  }

  static String getDeviceStatus(int channel, String quality) {
    return 'action=inner_define&channel=$channel&cmd=get_device_st&type=live&quality=$quality';
  }
}