import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'dart:core';
import 'foreground_task_handler.dart';
import 'signaling.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:flutter_foreground_task/flutter_foreground_task.dart';

/// CallSample类，继承自StatefulWidget，用于创建P2P通话示例界面
class CallSample extends StatefulWidget {
  static String tag = 'call_sample';
  final String host; // WebSocket服务器地址
  CallSample({required this.host}); // 构造函数，初始化服务器地址

  @override
  _CallSampleState createState() => _CallSampleState(); // 创建状态管理对象
}

/// _CallSampleState类，管理CallSample界面的状态
class _CallSampleState extends State<CallSample> {
  Signaling? _signaling; // 信令对象，用于处理WebSocket通信
  List<dynamic> _peers = []; // 对等方列表
  String? _selfId; // 当前用户的ID
  RTCVideoRenderer _localRenderer = RTCVideoRenderer(); // 本地视频渲染器
  RTCVideoRenderer _remoteRenderer = RTCVideoRenderer(); // 远程视频渲染器
  bool _inCalling = false; // 是否正在通话中
  Session? _session; // 当前通话会话
  bool _waitAccept = false; // 是否等待对方接受通话

  // ignore: unused_element
  _CallSampleState(); // 构造函数

  @override
  initState() {
    super.initState();
    initRenderers().then((_) {// 初始化视频渲染器
      // 等待初始化完成在连接
      _connect(context);// 连接到信令服务器
      //Android和ios启动后台保活服务
      if (Platform.isAndroid || Platform.isIOS) {
        _initForegroundTask();
        _startForegroundService();
      }
    });
  }

  void _initForegroundTask() {
    FlutterForegroundTask.init(
      androidNotificationOptions: AndroidNotificationOptions(
        channelId: 'foreground_service',
        channelName: '摄像头服务',
        channelDescription: '摄像头后台服务正在运行',
        onlyAlertOnce: true,
      ),
      iosNotificationOptions: const IOSNotificationOptions(
        showNotification: false,
        playSound: false,
      ),
      foregroundTaskOptions: ForegroundTaskOptions(
        eventAction: ForegroundTaskEventAction.repeat(10000), // 每10秒触发一次 repeat 事件
        autoRunOnBoot: true,
        allowWakeLock: true,
        allowWifiLock: true,
      ),
    );
  }

  Future<void> _startForegroundService() async {
    if (!await FlutterForegroundTask.isRunningService) {
      await FlutterForegroundTask.startService(
        notificationTitle: '摄像头服务运行中',
        notificationText: '点击返回应用',
        notificationIcon: null, // 使用默认图标
        notificationInitialRoute: '/CallSample', // 返回到指定页面
        callback: startForegroundTaskCallback,
      );
    }
  }
  @pragma('vm:entry-point')
  void startForegroundTaskCallback() {
    FlutterForegroundTask.setTaskHandler(ForegroundTaskHandler());
  }




  /// 初始化视频渲染器
  initRenderers() async {
    await _localRenderer.initialize();
    await _remoteRenderer.initialize();
  }

  @override
  deactivate() {
    super.deactivate();
    _signaling?.close(); // 关闭信令连接
    _localRenderer.dispose(); // 释放本地视频渲染器
    _remoteRenderer.dispose(); // 释放远程视频渲染器
  }

  /// 连接到信令服务器
  void _connect(BuildContext context) async {
    _signaling ??= Signaling(widget.host, context)..connect();
    _signaling?.onSignalingStateChange = (SignalingState state) {
      switch (state) {
        case SignalingState.ConnectionClosed:
        case SignalingState.ConnectionError:
        case SignalingState.ConnectionOpen:
          break;
      }
    };

    _signaling?.onConnectionFailed = (String reason) {
      // 连接失败显示错误信息
      _showConnectionFailedDialog(reason);
    };

    _signaling?.onCallStateChange = (Session session, CallState state) async {
      switch (state) {
        case CallState.CallStateNew:
          setState(() {
            _session = session;
          });
          break;
        case CallState.CallStateBye:
          if (_waitAccept) {
            print('peer reject');
            _waitAccept = false;
            Navigator.of(context).pop(false);
          }
          setState(() {
            _localRenderer.srcObject = null;
            _remoteRenderer.srcObject = null;
            _inCalling = false;
            _session = null;
          });
          break;
        case CallState.CallStateInvite:
          _waitAccept = true;
          _showInvateDialog();
          break;
        case CallState.CallStateConnected:
          if (_waitAccept) {
            _waitAccept = false;
            Navigator.of(context).pop(false);
          }
          setState(() {
            _inCalling = true;
          });
          break;
        case CallState.CallStateRinging:
          break;
      }
    };

    _signaling?.onPeersUpdate = ((event) {
      setState(() {
        _selfId = event['self'];
        _peers = event['peers'];
      });
    });

    _signaling?.onLocalStream = ((stream) {
      _localRenderer.srcObject = stream;
      setState(() {});
    });

    _signaling?.onAddRemoteStream = ((_, stream) {
      _remoteRenderer.srcObject = stream;
      setState(() {});
    });

    _signaling?.onRemoveRemoteStream = ((_, stream) {
      _remoteRenderer.srcObject = null;
    });
  }

  /// 显示连接失败的对话框
  Future<void> _showConnectionFailedDialog(String reason) async {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text("服务器连接失败"),
          content: Text(reason),
          actions: <Widget>[
            TextButton(
              child: Text("确定"),
              onPressed: () => Navigator.of(context).pop(),
            ),
          ],
        );
      },
    );
  }

  /// 显示等待对方接受通话的对话框
  Future<bool?> _showInvateDialog() {
    return showDialog<bool?>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text("正在呼叫"),
          content: Text("等待对方接听 喝杯Java稍等......"),
          actions: <Widget>[
            TextButton(
              child: Text("取消"),
              onPressed: () => Navigator.of(context).pop(false),
            ),
          ],
        );
      },
    );
  }


  /// 挂断通话
  _hangUp() {
    if (_session != null) {
      _signaling?.bye(_session!.sid);
    }
  }

  /// 切换摄像头
  _switchCamera() {
    _signaling?.switchCamera();
  }

  /// 静音麦克风
  _muteMic() {
    _signaling?.muteMic();
  }

  /// 构建对等方列表项
  _buildRow(context, peer) {
    var self = (peer['id'] == _selfId);
    return ListBody(children: <Widget>[
      ListTile(
        title: Text(self
            ? peer['name'] + ', ID: ${peer['id']} ' + ' [此设备]'
            : peer['name'] + ', ID: ${peer['id']} '),
        onTap: null,

        subtitle: Text('[' + peer['user_agent'] + ']'),
      ),
      Divider()
    ]);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('在线设备列表' +
            (_selfId != null ? ' [本机房间号 ($_selfId)] ' : '')),

      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
      floatingActionButton: _inCalling
          ? SizedBox(
          width: 150.0,
          child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: <Widget>[
                FloatingActionButton(
                  child: const Icon(Icons.switch_camera),
                  tooltip: '切换本机摄像头',
                  onPressed: _switchCamera,
                ),
                // FloatingActionButton(
                //   onPressed: _hangUp,
                //   tooltip: '挂断',
                //   child: Icon(Icons.call_end),
                //   backgroundColor: Colors.pink,
                // ),
                FloatingActionButton(
                  child: const Icon(Icons.mic_off),
                  tooltip: '静音',
                  onPressed: _muteMic,
                )
              ]))
          : null,
      body: _inCalling
          ? OrientationBuilder(builder: (context, orientation) {
        return Container(
          child: Stack(children: <Widget>[
            Positioned(
                left: 0.0,
                right: 0.0,
                top: 0.0,
                bottom: 0.0,
                child: Container(
                  margin: EdgeInsets.fromLTRB(0.0, 0.0, 0.0, 0.0),
                  width: MediaQuery.of(context).size.width,
                  height: MediaQuery.of(context).size.height,
                  child: RTCVideoView(_remoteRenderer),
                  decoration: BoxDecoration(color: Colors.black54),
                )),

          ]),
        );
      })
          : ListView.builder(
          shrinkWrap: true,
          padding: const EdgeInsets.all(0.0),
          itemCount: (_peers != null ? _peers.length : 0),
          itemBuilder: (context, i) {
            return _buildRow(context, _peers[i]);
          }),
    );
  }
}
