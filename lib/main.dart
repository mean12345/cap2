import 'dart:async';
import 'dart:developer';
import 'package:flutter/material.dart';
import 'package:flutter_naver_map/flutter_naver_map.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:dangq/login/login.dart';
import 'package:intl/date_symbol_data_local.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized(); // 비동기 초기화를 위해 필요
  await initializeDateFormatting('ko_KR', null);
  await dotenv.load(fileName: "assets/.env");
  await _initialize();
  runApp(const MyApp());
}

Future<void> _initialize() async {
  WidgetsFlutterBinding.ensureInitialized();
  String mapKey = dotenv.env['MAP_KEY'] ?? '';
  if (mapKey.isEmpty) {
    log("MAP_KEY is not found in .env file", name: "onAuthFailed");
    return;
  }

  await NaverMapSdk.instance.initialize(
    clientId: mapKey,
    onAuthFailed: (e) => log("네이버맵 인증오류 : $e", name: "onAuthFailed"),
  );
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'DangQ',
      theme: ThemeData(
        primarySwatch: Colors.blue,
        visualDensity: VisualDensity.adaptivePlatformDensity,
      ),
      home: const PermissionRequestPage(),
    );
  }
}

class PermissionRequestPage extends StatefulWidget {
  const PermissionRequestPage({Key? key}) : super(key: key);

  @override
  _PermissionRequestPageState createState() => _PermissionRequestPageState();
}

class _PermissionRequestPageState extends State<PermissionRequestPage> {
  @override
  void initState() {
    super.initState();
    _requestLocationPermission();
  }

  void _requestLocationPermission() async {
    var status = await Permission.location.status;
    if (status.isDenied) {
      var requestStatus = await Permission.location.request();
      if (requestStatus.isPermanentlyDenied) {
        openAppSettings();
      }
    } else if (status.isGranted) {
      _navigateToLoginPage();
    }
  }

  void _navigateToLoginPage() {
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (context) => Login()),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: const Center(child: CircularProgressIndicator()),
    );
  }
}
