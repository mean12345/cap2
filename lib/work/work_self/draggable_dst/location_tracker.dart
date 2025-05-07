import 'package:flutter/material.dart';
import 'package:flutter_naver_map/flutter_naver_map.dart';
import 'package:geolocator/geolocator.dart';
import 'dart:async';
import 'package:http/http.dart' as http;
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'dart:convert';

//실시간 위치추적, 거리계산, 경로저장 기능을 담당하는 클래스

class LocationTracker {
  final NaverMapController mapController;
  final String username;
  final Function(double) onDistanceUpdate;

  List<NLatLng> path = [];
  double totalDistance = 0.0;
  DateTime? startTime;
  bool isRecording = false;
  NLatLng? lastPosition;
  Position? currentPosition;
  Timer? _locationTimer;

  LocationTracker({
    required this.mapController,
    required this.username,
    required this.onDistanceUpdate,
  });

  Future<void> getCurrentLocation() async {
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      throw Exception('위치 서비스가 비활성화되어 있습니다.');
    }

    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        throw Exception('위치 권한이 거부되었습니다.');
      }
    }

    if (permission == LocationPermission.deniedForever) {
      throw Exception('위치 권한이 영구적으로 거부되었습니다.');
    }

    try {
      currentPosition = await Geolocator.getCurrentPosition(
          desiredAccuracy: LocationAccuracy.high);
    } catch (e) {
      throw Exception('위치를 가져오는 데 실패했습니다: $e');
    }
  }

  void startTracking() async {
    if (!await Geolocator.isLocationServiceEnabled()) return;

    if (await Geolocator.checkPermission() == LocationPermission.denied) {
      if (await Geolocator.requestPermission() ==
          LocationPermission.deniedForever) {
        return;
      }
    }

    await getCurrentLocation(); // 초기 위치 가져오기
    if (currentPosition != null) {
      lastPosition =
          NLatLng(currentPosition!.latitude, currentPosition!.longitude);
      path.add(lastPosition!);
    }

    _locationTimer?.cancel();
    _locationTimer = Timer.periodic(Duration(seconds: 1), (timer) async {
      if (!isRecording) {
        timer.cancel();
        return;
      }

      await getCurrentLocation(); // 현재 위치 업데이트
      if (currentPosition != null) {
        NLatLng newLocation = NLatLng(
          currentPosition!.latitude,
          currentPosition!.longitude,
        );

        if (lastPosition != null) {
          double distance = Geolocator.distanceBetween(
            lastPosition!.latitude,
            lastPosition!.longitude,
            newLocation.latitude,
            newLocation.longitude,
          );

          totalDistance += distance;
          onDistanceUpdate(totalDistance);
        }

        path.add(newLocation);

        NPathOverlay pathOverlay = NPathOverlay(
          id: "test",
          coords: path,
        );

        mapController.addOverlay(pathOverlay);
        lastPosition = newLocation;
      }
    });
  }

  Future<void> saveTrackData(double speed) async {
    if (startTime == null || path.isEmpty) return;

    final endTime = DateTime.now();
    final duration = endTime.difference(startTime!);
    final durationInSeconds = duration.inSeconds > 0 ? duration.inSeconds : 1;

    final String baseUrl = dotenv.get('BASE_URL');

    try {
      final response = await http.post(
        Uri.parse('$baseUrl/tracking/saveTrack'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          'username': username,
          'startTime': startTime!.toIso8601String(),
          'endTime': endTime.toIso8601String(),
          'distance': totalDistance.roundToDouble(),
          'speed': speed,
        }),
      );

      if (response.statusCode == 200) {
        debugPrint('트랙 데이터 저장 성공');
        debugPrint('총 거리: $totalDistance m');
        debugPrint('평균 속도: $speed km/h');
      } else {
        debugPrint('트랙 데이터 저장 실패: ${response.statusCode}');
      }
    } catch (e) {
      debugPrint('트랙 데이터 저장 중 오류: $e');
    }
  }

  void startRecording() {
    isRecording = true;
    startTime = DateTime.now();
    path.clear();
    totalDistance = 0.0;
    lastPosition = null;
    startTracking();
  }

  void stopRecording() {
    if (!isRecording) return;
    isRecording = false;
    _locationTimer?.cancel();
  }

  @override
  void dispose() {
    _locationTimer?.cancel();
  }
}
