import 'package:flutter_foreground_task/flutter_foreground_task.dart';

class ForegroundTaskHandler extends TaskHandler {
  @override
  Future<void> onStart(DateTime timestamp, TaskStarter starter) async {
    print("Foreground task started at $timestamp");

    // 可以在这里初始化你的服务逻辑，例如连接信令服务器等
    FlutterForegroundTask.updateService(
      notificationTitle: '摄像头服务运行中',
      notificationText: '服务正在后台运行...',
    );
  }

  @override
  void onRepeatEvent(DateTime timestamp) {
    // 每隔一段时间触发一次，时间由 ForegroundTaskOptions 设置决定
    print("Repeat event triggered at $timestamp");
  }

  @override
  Future<void> onDestroy(DateTime timestamp, bool isTimeout) async {
    print("Foreground task destroyed at $timestamp (isTimeout: $isTimeout)");
    // 清理资源或保存状态
  }

  @override
  void onReceiveData(Object data) {
    print("Received data from UI: $data");
    // 处理来自 UI 层的数据通信
  }

  @override
  void onNotificationButtonPressed(String id) {
    print("Notification button pressed: $id");
    // 如果你在通知栏加了按钮，可以在这里处理点击事件
  }

  @override
  void onNotificationPressed() {
    print("Notification pressed");
    // 用户点击通知栏跳回 App
    FlutterForegroundTask.launchApp();
  }

  @override
  void onNotificationDismissed() {
    print("Notification dismissed");
    // 通知被用户清除时触发
  }
}
