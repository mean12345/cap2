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
  final int dogId; // 추가
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
    required this.dogId,
    required this.onDistanceUpdate,
  });
// 거리 계산 보조 함수
  double _perpendicularDistance(
      NLatLng point, NLatLng lineStart, NLatLng lineEnd) {
    double dx = lineEnd.latitude - lineStart.latitude;
    double dy = lineEnd.longitude - lineStart.longitude;

    if (dx == 0 && dy == 0) {
      return Geolocator.distanceBetween(
        point.latitude,
        point.longitude,
        lineStart.latitude,
        lineStart.longitude,
      );
    }

    double t = ((point.latitude - lineStart.latitude) * dx +
            (point.longitude - lineStart.longitude) * dy) /
        (dx * dx + dy * dy);

    if (t < 0)
      t = 0;
    else if (t > 1) t = 1;

    double projLat = lineStart.latitude + t * dx;
    double projLng = lineStart.longitude + t * dy;

    return Geolocator.distanceBetween(
      point.latitude,
      point.longitude,
      projLat,
      projLng,
    );
  }

// Douglas-Peucker 알고리즘 구현
  List<NLatLng> douglasPeucker(List<NLatLng> points, double epsilon) {
    if (points.length < 3) return points;

    double maxDistance = 0.0;
    int index = 0;

    for (int i = 1; i < points.length - 1; i++) {
      double distance =
          _perpendicularDistance(points[i], points[0], points.last);
      if (distance > maxDistance) {
        index = i;
        maxDistance = distance;
      }
    }

    if (maxDistance > epsilon) {
      List<NLatLng> recResults1 =
          douglasPeucker(points.sublist(0, index + 1), epsilon);
      List<NLatLng> recResults2 =
          douglasPeucker(points.sublist(index, points.length), epsilon);

      return [
        ...recResults1.sublist(0, recResults1.length - 1),
        ...recResults2
      ];
    } else {
      return [points.first, points.last];
    }
  }

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

          // 10미터 이상 움직였을 때만 거리 누적 및 경로에 추가
          if (distance >= 10) {
            totalDistance += distance;
            onDistanceUpdate(totalDistance);
            path.add(newLocation);

            NPathOverlay pathOverlay = NPathOverlay(
              id: "test",
              coords: path,
            );

            mapController.addOverlay(pathOverlay);
            lastPosition = newLocation;
          }
        } else {
          // lastPosition이 null일 때 (초기 위치 설정)
          lastPosition = newLocation;
          path.add(newLocation);
        }
      }
    });
  }

  Future<void> saveTrackData() async {
    if (startTime == null || path.isEmpty) return;

    final endTime = DateTime.now();
    final durationSeconds = endTime.difference(startTime!).inSeconds;
    if (durationSeconds == 0) return;

    final double averageSpeed = (totalDistance / durationSeconds) * 3.6;
    final double roundedSpeed =
        double.parse(averageSpeed.toStringAsFixed(2)); // 소수점 둘째 자리 반올림

    final String baseUrl = dotenv.get('BASE_URL');

    List<NLatLng> simplifiedPath = douglasPeucker(path, 10);

    List<Map<String, double>> pathJson = simplifiedPath
        .map((p) => {'latitude': p.latitude, 'longitude': p.longitude})
        .toList();

    try {
      final response = await http.post(
        Uri.parse('$baseUrl/tracking/saveTrack'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          'username': username,
          'dog_id': dogId,
          'startTime': startTime!.toIso8601String(),
          'endTime': endTime.toIso8601String(),
          'distance': totalDistance.roundToDouble(),
          'speed': roundedSpeed,
          'path_data': pathJson,
        }),
      );

      if (response.statusCode == 200) {
        debugPrint('트랙 데이터 저장 성공');
        debugPrint('총 거리: $totalDistance m');
        debugPrint('평균 속도: $roundedSpeed km/h');
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
