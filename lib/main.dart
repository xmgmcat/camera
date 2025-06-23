import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'call_sample.dart';
import 'server.dart';
import 'foreground_task_handler.dart';
import 'package:flutter_foreground_task/flutter_foreground_task.dart';


void main() => runApp(MyApp());

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(

      initialRoute: 'home', // 设置初始路由设置主页为 home
      routes: {
        'home': (context) => HomeScreen(),
        'CallSample': (context) => CallSample(host: Server.host), // 定义 CallSample 路由
      },
    );
  }
}

class HomeScreen extends StatefulWidget {
  @override
  _HomeScreenState createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  bool _isInitialized = false;

  @override
  void initState() {
    super.initState();
    _initSharedPreferences().then((_) {
      setState(() {
        _isInitialized = true;
        requestPermissions(); //申请摄像头，录音权限
        //初始化设置TaskHandler
        WidgetsFlutterBinding.ensureInitialized();
        // 初始化通信端口（用于前后台数据通信）
        FlutterForegroundTask.initCommunicationPort();
        // 设置 TaskHandler
        FlutterForegroundTask.setTaskHandler(ForegroundTaskHandler());

      });
    });
  }

  ///动态申请权限
  Future<void> requestPermissions() async {
    await [Permission.camera, Permission.microphone].request();
  }

  /// 初始化读取SharedPreferences数据，并设置到服务变量仓库
  Future<void> _initSharedPreferences() async {
    final prefs = await SharedPreferences.getInstance();
    Server.host = prefs.getString('host') ?? '';
    //如果没有存入stun地址，则使用默认的stun地址
    Server.stunurl = prefs.getString('stun') ?? 'stun:stun.l.google.com:19302';
    Server.room = prefs.getString('room') ?? '';
  }

  @override
  Widget build(BuildContext context) {
    if (!_isInitialized) {
      return Scaffold(
        body: Center(
          child: CircularProgressIndicator(),
        ),
      );
    }

    // 在build方法中检查Signaling.host是否为空
    if (Server.host.isEmpty && Server.room.isEmpty) {
      // 如果信令服务器地址为空，则弹出设置对话框
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _showSettingsDialog(context);
      });
    } else {
      // 如果信令服务器地址不为空，跳转设备列表
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _callNva(); //跳转
      });
    }

    return Scaffold(
      appBar: AppBar(
        title: Text('摄像头端'),
        actions: [
          IconButton(
            icon: Icon(Icons.settings),
            onPressed: () {
              _showSettingsDialog(context);
            },
          ),
        ],
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(''),
            SizedBox(height: 20),
            OutlinedButton(
              onPressed: () {
                if (Server.host.isNotEmpty && Server.stunurl.isNotEmpty && Server.room.isNotEmpty) {
                  _callNva(); // 如果三个数据都不为空，进入 call
                } else {
                  _showSettingsDialog(context); // 否则弹出设置对话框
                }
              },
              child: Text('进入房间'),
            ),
          ],
        ),
      ),
    );
  }

  /// 弹出设置对话框
  void _showSettingsDialog(BuildContext context) async {
    final TextEditingController controller1 = TextEditingController(text: Server.host); // 直接从全局变量获取值
    final TextEditingController controller2 = TextEditingController(text: Server.stunurl); // 直接从全局变量获取值
    final TextEditingController controller3 = TextEditingController(text: Server.room); // 直接从全局变量获取值
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text('设置'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: controller1,
                decoration: InputDecoration(labelText: '信令服务器地址'),
              ),
              TextField(
                controller: controller2,
                decoration: InputDecoration(labelText: 'stun服务器地址'),
              ),
              TextField(
                controller: controller3,
                decoration: InputDecoration(labelText: '房间号'),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () async {
                if (controller1.text.isEmpty || controller2.text.isEmpty || controller3.text.isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('缺少必要数据')),
                  );
                  return;
                }
                // 保存数据到本地
                await _saveData(controller1.text, controller2.text, controller3.text);
                Navigator.of(context).pop();
                // 跳转到视频设备列表
                _callNva();
              },
              child: Text('保存'),
            ),
          ],
        );
      },
    );
  }

  /// 保存数据到 SharedPreferences
  Future<void> _saveData(String value1, String value2, String value3) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('host', value1);
    await prefs.setString('stun', value2);
    await prefs.setString('room', value3);
    //首次打开不存在数据，所以在第一次保存数据时，数据没有传到全局全局变量去，
    // 所以要更新全局变量
    _initSharedPreferences();
  }

  Future<void> _callNva() async {
    Navigator.pushNamed(context, 'CallSample');
  }

}