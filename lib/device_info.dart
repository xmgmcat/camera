import 'dart:io';

class DeviceInfo {
  static String get label {
    return '设备： ' +
        '(' +
        Platform.localHostname +
        ")";
  }

  static String get userAgent {
    return '平台：' + Platform.operatingSystem;
  }
}
