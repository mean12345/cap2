// lib/main.dart

import 'dart:async';
import 'dart:developer';

import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_naver_map/flutter_naver_map.dart';
import 'package:permission_handler/permission_handler.dart';

import 'login/login.dart'; // 로그인 화면 (이미 구현된 상태라 가정)
import 'pages/navigation/route_select_page.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // .env 파일 로드 (assets/.env 에 MAP_KEY, BASE_URL 등)
  await dotenv.load(fileName: "assets/.env");

  // 네이버맵 SDK 초기화
  await _initializeMapSdk();

  runApp(const MyApp());
}

Future<void> _initializeMapSdk() async {
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
      debugShowCheckedModeBanner: false,
    );
  }
}

/// ─────────────────────────────────────────────────────────
/// 권한 요청 화면: 위치 권한 허용 후 → 로그인 화면으로 이동
/// ─────────────────────────────────────────────────────────
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
      } else if (requestStatus.isGranted) {
        _navigateToLoginPage();
      }
    } else if (status.isGranted) {
      _navigateToLoginPage();
    }
  }

  void _navigateToLoginPage() {
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (context) => const Login()),
    );
  }

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(child: CircularProgressIndicator()),
    );
  }
}
