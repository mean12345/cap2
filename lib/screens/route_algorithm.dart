import 'package:flutter/material.dart';
import 'package:flutter_naver_map/flutter_naver_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'dart:math' as math;
import 'dart:async';

class RouteWithStopoverPage extends StatefulWidget {
  const RouteWithStopoverPage({super.key});

  @override
  State<RouteWithStopoverPage> createState() => _RouteWithStopoverPageState();
}

enum MarkerType { stopover, good, bad }

enum WalkingState { planning, walking, paused, completed }

class SmartMarker {
  final String id;
  final NLatLng position;
  final MarkerType type;
  final NMarker marker;

  SmartMarker({
    required this.id,
    required this.position,
    required this.type,
    required this.marker,
  });
}

class WalkingStats {
  final Duration duration;
  final double distance;
  final int steps;
  final int visitedWaypoints;
  final int totalWaypoints;

  WalkingStats({
    required this.duration,
    required this.distance,
    required this.steps,
    required this.visitedWaypoints,
    required this.totalWaypoints,
  });
}

class _RouteWithStopoverPageState extends State<RouteWithStopoverPage> {
  NaverMapController? _mapController;
  NLatLng? _start;
  NLatLng? _end;
  final List<SmartMarker> _smartMarkers = [];
  NMarker? _startMarker;
  NMarker? _endMarker;
  MarkerType _selectedMarkerType = MarkerType.stopover;

  // 경로 표시를 위한 변수들
  List<NLatLng> _routePath = [];
  NPolylineOverlay? _routePolyline;
  bool _isRouteVisible = false;

  // 산책 관련 변수들
  WalkingState _walkingState = WalkingState.planning;
  StreamSubscription<Position>? _positionSubscription;
  NLatLng? _currentPosition;
  NMarker? _currentPositionMarker;
  DateTime? _walkingStartTime;
  DateTime? _walkingEndTime;
  double _totalDistance = 0.0;
  int _currentWaypointIndex = 0;
  List<NLatLng> _visitedPositions = [];
  NPolylineOverlay? _walkingTrackPolyline;
  Timer? _walkingTimer;
  Duration _walkingDuration = Duration.zero;

  // 알고리즘 관련 상수
  static const double DETECTION_RADIUS = 1000.0; // 1km in meters
  static const double WAYPOINT_REACH_THRESHOLD =
      50.0; // 50m to consider waypoint reached
  static const double ROUTE_DEVIATION_THRESHOLD = 100.0; // 100m from route

  @override
  void initState() {
    super.initState();
    _setCurrentLocation();
  }

  @override
  void dispose() {
    _positionSubscription?.cancel();
    _walkingTimer?.cancel();
    super.dispose();
  }

  Future<void> _setCurrentLocation() async {
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) return;

    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied ||
        permission == LocationPermission.deniedForever) {
      permission = await Geolocator.requestPermission();
      if (permission != LocationPermission.whileInUse &&
          permission != LocationPermission.always) {
        return;
      }
    }

    Position position = await Geolocator.getCurrentPosition();
    NLatLng current = NLatLng(position.latitude, position.longitude);

    setState(() {
      _start = current;
      _end = current;
      _currentPosition = current;

      _startMarker = NMarker(
        id: 'start',
        position: _start!,
        iconTintColor: Colors.blue,
        caption: NOverlayCaption(text: '출발지'),
      );

      _endMarker = NMarker(
        id: 'end',
        position: _end!,
        iconTintColor: Colors.green,
        caption: NOverlayCaption(text: '도착지'),
      );

      _currentPositionMarker = NMarker(
        id: 'current_position',
        position: current,
        iconTintColor: Colors.purple,
        caption: NOverlayCaption(text: '현재 위치'),
      );
    });

    if (_mapController != null) {
      _updateMarkersOnMap();
    }
  }

  void _onMapTapped(NPoint point, NLatLng latLng) {
    if (_walkingState == WalkingState.planning) {
      _addSmartMarker(latLng, _selectedMarkerType);
    }
  }

  Future<void> _updateMarkersOnMap() async {
    if (_mapController == null) return;

    await _mapController!.clearOverlays();

    if (_startMarker != null) {
      await _mapController!.addOverlay(_startMarker!);
    }

    if (_endMarker != null) {
      await _mapController!.addOverlay(_endMarker!);
    }

    if (_currentPositionMarker != null &&
        _walkingState != WalkingState.planning) {
      await _mapController!.addOverlay(_currentPositionMarker!);
    }

    for (final smartMarker in _smartMarkers) {
      await _mapController!.addOverlay(smartMarker.marker);
    }

    if (_routePolyline != null && _isRouteVisible) {
      await _mapController!.addOverlay(_routePolyline!);
    }

    if (_walkingTrackPolyline != null) {
      await _mapController!.addOverlay(_walkingTrackPolyline!);
    }
  }

  void _addSmartMarker(NLatLng latLng, MarkerType type) {
    final id =
        '${type.name}_${_smartMarkers.where((m) => m.type == type).length}';

    Color color;
    String caption;

    switch (type) {
      case MarkerType.stopover:
        color = Colors.yellow;
        caption =
            '경유지 ${_smartMarkers.where((m) => m.type == MarkerType.stopover).length + 1}';
        break;
      case MarkerType.good:
        color = Colors.lightGreen;
        caption =
            'Good ${_smartMarkers.where((m) => m.type == MarkerType.good).length + 1}';
        break;
      case MarkerType.bad:
        color = Colors.red;
        caption =
            'Bad ${_smartMarkers.where((m) => m.type == MarkerType.bad).length + 1}';
        break;
    }

    final marker = NMarker(
      id: id,
      position: latLng,
      iconTintColor: color,
      caption: NOverlayCaption(text: caption),
    );

    final smartMarker = SmartMarker(
      id: id,
      position: latLng,
      type: type,
      marker: marker,
    );

    setState(() {
      _smartMarkers.add(smartMarker);
    });

    _updateMarkersOnMap();
  }

  // 두 좌표 간의 거리 계산 (Haversine formula)
  double _calculateDistance(NLatLng point1, NLatLng point2) {
    return Geolocator.distanceBetween(
      point1.latitude,
      point1.longitude,
      point2.latitude,
      point2.longitude,
    );
  }

  // 경로상의 점들과 마커들의 근접성 확인
  List<SmartMarker> _findNearbyMarkers(
      List<NLatLng> routePoints, MarkerType type) {
    List<SmartMarker> nearbyMarkers = [];

    for (final marker in _smartMarkers.where((m) => m.type == type)) {
      bool isNearRoute = false;

      for (final routePoint in routePoints) {
        if (_calculateDistance(routePoint, marker.position) <=
            DETECTION_RADIUS) {
          isNearRoute = true;
          break;
        }
      }

      if (isNearRoute) {
        nearbyMarkers.add(marker);
      }
    }

    return nearbyMarkers;
  }

  // 스마트 경로 생성 알고리즘
  List<NLatLng> _generateSmartRoute() {
    if (_start == null || _end == null) return [];

    List<NLatLng> waypoints = [_start!];

    // 기존 경유지 추가
    waypoints.addAll(_smartMarkers
        .where((m) => m.type == MarkerType.stopover)
        .map((m) => m.position));

    // Good 마커들 중에서 경로에 가까운 것들을 경유지로 추가
    final goodMarkers =
        _smartMarkers.where((m) => m.type == MarkerType.good).toList();

    // 간단한 그리디 알고리즘으로 가까운 Good 마커들을 순서대로 추가
    List<NLatLng> currentPath = List.from(waypoints);
    currentPath.add(_end!);

    for (final goodMarker in goodMarkers) {
      // 현재 경로에서 이 Good 마커까지의 최단거리 확인
      double minDistance = double.infinity;
      int insertIndex = -1;

      for (int i = 0; i < currentPath.length - 1; i++) {
        double distanceToMarker =
            _calculateDistance(currentPath[i], goodMarker.position);
        if (distanceToMarker <= DETECTION_RADIUS &&
            distanceToMarker < minDistance) {
          minDistance = distanceToMarker;
          insertIndex = i + 1;
        }
      }

      if (insertIndex != -1) {
        currentPath.insert(insertIndex, goodMarker.position);
      }
    }

    return currentPath;
  }

  // Bad 마커 우회를 위한 경로 조정
  List<NLatLng> _adjustRouteForBadMarkers(List<NLatLng> originalRoute) {
    List<NLatLng> adjustedRoute = List.from(originalRoute);
    final badMarkers =
        _smartMarkers.where((m) => m.type == MarkerType.bad).toList();

    for (final badMarker in badMarkers) {
      List<NLatLng> newRoute = [];

      for (int i = 0; i < adjustedRoute.length; i++) {
        newRoute.add(adjustedRoute[i]);

        // 다음 점이 있고, 현재 점에서 다음 점으로의 경로가 Bad 마커와 너무 가까운 경우
        if (i < adjustedRoute.length - 1) {
          NLatLng current = adjustedRoute[i];
          NLatLng next = adjustedRoute[i + 1];

          // 중점 계산
          NLatLng midPoint = NLatLng(
            (current.latitude + next.latitude) / 2,
            (current.longitude + next.longitude) / 2,
          );

          if (_calculateDistance(midPoint, badMarker.position) <=
              DETECTION_RADIUS) {
            // 우회 지점 생성 (Bad 마커로부터 수직으로 DETECTION_RADIUS * 1.5 만큼 떨어진 지점)
            double bearing = _calculateBearing(current, next);
            double perpendicularBearing = bearing + 90; // 수직 방향

            NLatLng detourPoint = _calculateDestination(
                midPoint, perpendicularBearing, DETECTION_RADIUS * 1.5);

            newRoute.add(detourPoint);
          }
        }
      }

      adjustedRoute = newRoute;
    }

    return adjustedRoute;
  }

  // 방향각 계산
  double _calculateBearing(NLatLng start, NLatLng end) {
    double lat1 = start.latitude * math.pi / 180;
    double lat2 = end.latitude * math.pi / 180;
    double deltaLng = (end.longitude - start.longitude) * math.pi / 180;

    double y = math.sin(deltaLng) * math.cos(lat2);
    double x = math.cos(lat1) * math.sin(lat2) -
        math.sin(lat1) * math.cos(lat2) * math.cos(deltaLng);

    return math.atan2(y, x) * 180 / math.pi;
  }

  // 특정 거리와 방향으로 새로운 좌표 계산
  NLatLng _calculateDestination(
      NLatLng start, double bearing, double distance) {
    double lat1 = start.latitude * math.pi / 180;
    double lng1 = start.longitude * math.pi / 180;
    double bearingRad = bearing * math.pi / 180;
    double earthRadius = 6371000; // Earth radius in meters

    double lat2 = math.asin(math.sin(lat1) * math.cos(distance / earthRadius) +
        math.cos(lat1) *
            math.sin(distance / earthRadius) *
            math.cos(bearingRad));

    double lng2 = lng1 +
        math.atan2(
            math.sin(bearingRad) *
                math.sin(distance / earthRadius) *
                math.cos(lat1),
            math.cos(distance / earthRadius) - math.sin(lat1) * math.sin(lat2));

    return NLatLng(lat2 * 180 / math.pi, lng2 * 180 / math.pi);
  }

  Future<void> _clearRoute() async {
    if (_mapController != null && _routePolyline != null) {
      await _mapController!.deleteOverlay(_routePolyline!.info);
    }

    setState(() {
      _routePath.clear();
      _routePolyline = null;
      _isRouteVisible = false;
    });
  }

  Future<void> _displayRoute(List<NLatLng> routePoints) async {
    if (_mapController == null || routePoints.isEmpty) return;

    await _clearRoute();

    final polyline = NPolylineOverlay(
      id: 'route_polyline',
      coords: routePoints,
      color: Colors.blue,
      width: 5,
    );

    await _mapController!.addOverlay(polyline);

    setState(() {
      _routePath = routePoints;
      _routePolyline = polyline;
      _isRouteVisible = true;
    });

    await _fitCameraToRoute(routePoints);
  }

  Future<void> _fitCameraToRoute(List<NLatLng> points) async {
    if (_mapController == null || points.isEmpty) return;

    double minLat = points.first.latitude;
    double maxLat = points.first.latitude;
    double minLng = points.first.longitude;
    double maxLng = points.first.longitude;

    for (final point in points) {
      minLat = minLat < point.latitude ? minLat : point.latitude;
      maxLat = maxLat > point.latitude ? maxLat : point.latitude;
      minLng = minLng < point.longitude ? minLng : point.longitude;
      maxLng = maxLng > point.longitude ? maxLng : point.longitude;
    }

    const double padding = 0.001;
    final NLatLngBounds bounds = NLatLngBounds(
      southWest: NLatLng(minLat - padding, minLng - padding),
      northEast: NLatLng(maxLat + padding, maxLng + padding),
    );

    await _mapController!.updateCamera(
        NCameraUpdate.fitBounds(bounds, padding: const EdgeInsets.all(50)));
  }

  Future<void> _requestSmartRoute() async {
    if (_start == null || _end == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('출발지와 도착지가 설정되어야 합니다.')),
      );
      return;
    }

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(child: CircularProgressIndicator()),
    );

    try {
      // 스마트 경로 생성
      List<NLatLng> smartRoute = _generateSmartRoute();

      // Bad 마커 우회 경로 적용
      smartRoute = _adjustRouteForBadMarkers(smartRoute);

      // 서버에 요청할 데이터 준비
      final stopovers =
          smartRoute.sublist(1, smartRoute.length - 1).map((point) {
        return {'lat': point.latitude, 'lng': point.longitude};
      }).toList();

      final body = jsonEncode({
        'start': {'lat': _start!.latitude, 'lng': _start!.longitude},
        'end': {'lat': _end!.latitude, 'lng': _end!.longitude},
        'stopovers': stopovers,
      });

      final String baseUrl = dotenv.get('BASE_URL');
      final response = await http.post(
        Uri.parse('$baseUrl/direction/getPath'),
        headers: {'Content-Type': 'application/json'},
        body: body,
      );

      Navigator.of(context).pop();

      if (response.statusCode == 200) {
        final decoded = jsonDecode(response.body);
        final List<dynamic> pathData = decoded['path'];

        final List<NLatLng> routePoints = pathData.map((point) {
          return NLatLng(point['lat'].toDouble(), point['lng'].toDouble());
        }).toList();

        await _displayRoute(routePoints);

        // 분석 결과 표시
        final goodCount =
            _smartMarkers.where((m) => m.type == MarkerType.good).length;
        final badCount =
            _smartMarkers.where((m) => m.type == MarkerType.bad).length;

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('스마트 경로 생성 완료!\n'
                'Good 마커: ${goodCount}개, Bad 마커: ${badCount}개 고려됨\n'
                '이제 산책을 시작할 수 있습니다!'),
            backgroundColor: Colors.green,
            duration: const Duration(seconds: 3),
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('서버 오류: ${response.statusCode}')),
        );
      }
    } catch (e) {
      Navigator.of(context).pop();
      print('HTTP 오류: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('경로 요청 중 오류 발생')),
      );
    }
  }

  // 산책 시작
  Future<void> _startWalking() async {
    if (!_isRouteVisible || _routePath.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('먼저 경로를 생성해주세요.')),
      );
      return;
    }

    setState(() {
      _walkingState = WalkingState.walking;
      _walkingStartTime = DateTime.now();
      _totalDistance = 0.0;
      _currentWaypointIndex = 0;
      _visitedPositions.clear();
      _walkingDuration = Duration.zero;
    });

    // 위치 추적 시작
    _positionSubscription = Geolocator.getPositionStream(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: 5, // 5미터마다 업데이트
      ),
    ).listen(_onPositionUpdate);

    // 타이머 시작
    _walkingTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_walkingState == WalkingState.walking && _walkingStartTime != null) {
        setState(() {
          _walkingDuration = DateTime.now().difference(_walkingStartTime!);
        });
      }
    });

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('산책이 시작되었습니다! 안전한 산책하세요.'),
        backgroundColor: Colors.green,
      ),
    );
  }

  // 위치 업데이트 처리
  void _onPositionUpdate(Position position) {
    final newPosition = NLatLng(position.latitude, position.longitude);

    setState(() {
      if (_currentPosition != null) {
        // 이동 거리 계산
        double distance = _calculateDistance(_currentPosition!, newPosition);
        _totalDistance += distance;
      }

      _currentPosition = newPosition;
      _visitedPositions.add(newPosition);

      // 현재 위치 마커 업데이트
      _currentPositionMarker = NMarker(
        id: 'current_position',
        position: newPosition,
        iconTintColor: Colors.purple,
        caption: NOverlayCaption(text: '현재 위치'),
      );
    });

    // 경로 이탈 확인
    _checkRouteDeviation(newPosition);

    // 다음 경유지 도달 확인
    _checkWaypointReached(newPosition);

    // 산책 경로 표시 업데이트
    _updateWalkingTrack();

    // 마커 업데이트
    _updateMarkersOnMap();

    // 카메라를 현재 위치로 이동
    if (_mapController != null) {
      _mapController!.updateCamera(
        NCameraUpdate.scrollAndZoomTo(target: newPosition, zoom: 16),
      );
    }
  }

  // 경로 이탈 확인
  void _checkRouteDeviation(NLatLng currentPos) {
    if (_routePath.isEmpty) return;

    double minDistance = double.infinity;
    for (final routePoint in _routePath) {
      double distance = _calculateDistance(currentPos, routePoint);
      if (distance < minDistance) {
        minDistance = distance;
      }
    }

    if (minDistance > ROUTE_DEVIATION_THRESHOLD) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('경로에서 ${minDistance.toInt()}m 벗어났습니다. 경로를 확인해주세요.'),
          backgroundColor: Colors.orange,
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }

  // 경유지 도달 확인
  void _checkWaypointReached(NLatLng currentPos) {
    if (_currentWaypointIndex >= _routePath.length) return;

    NLatLng nextWaypoint = _routePath[_currentWaypointIndex];
    double distance = _calculateDistance(currentPos, nextWaypoint);

    if (distance <= WAYPOINT_REACH_THRESHOLD) {
      setState(() {
        _currentWaypointIndex++;
      });

      if (_currentWaypointIndex >= _routePath.length) {
        // 모든 경유지 완료
        _completeWalking();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('경유지 ${_currentWaypointIndex}에 도달했습니다!'),
            backgroundColor: Colors.green,
            duration: const Duration(seconds: 2),
          ),
        );
      }
    }
  }

  // 산책 경로 표시 업데이트
  Future<void> _updateWalkingTrack() async {
    if (_mapController == null || _visitedPositions.length < 2) return;

    // 기존 트랙 삭제
    if (_walkingTrackPolyline != null) {
      await _mapController!.deleteOverlay(_walkingTrackPolyline!.info);
    }

    // 새 트랙 생성
    _walkingTrackPolyline = NPolylineOverlay(
      id: 'walking_track',
      coords: _visitedPositions,
      color: Colors.red,
      width: 3,
    );

    await _mapController!.addOverlay(_walkingTrackPolyline!);
  }

  // 산책 일시정지/재개
  void _toggleWalkingPause() {
    setState(() {
      if (_walkingState == WalkingState.walking) {
        _walkingState = WalkingState.paused;
        _positionSubscription?.pause();
      } else if (_walkingState == WalkingState.paused) {
        _walkingState = WalkingState.walking;
        _positionSubscription?.resume();
      }
    });
  }

  // 산책 완료
  void _completeWalking() {
    setState(() {
      _walkingState = WalkingState.completed;
      _walkingEndTime = DateTime.now();
    });

    _positionSubscription?.cancel();
    _walkingTimer?.cancel();

    _showWalkingCompletedDialog();
  }

  // 산책 강제 종료
  void _stopWalking() {
    _positionSubscription?.cancel();
    _walkingTimer?.cancel();

    setState(() {
      _walkingState = WalkingState.planning;
      _walkingStartTime = null;
      _walkingEndTime = null;
      _totalDistance = 0.0;
      _currentWaypointIndex = 0;
      _visitedPositions.clear();
      _walkingDuration = Duration.zero;
    });

    // 산책 트랙 삭제
    if (_mapController != null && _walkingTrackPolyline != null) {
      _mapController!.deleteOverlay(_walkingTrackPolyline!.info);
      _walkingTrackPolyline = null;
    }

    _updateMarkersOnMap();
  }

  // 산책 완료 다이얼로그
  void _showWalkingCompletedDialog() {
    final stats = WalkingStats(
      duration: _walkingDuration,
      distance: _totalDistance,
      steps: (_totalDistance / 0.762).round(), // 평균 보폭 76.2cm 기준
      visitedWaypoints: _currentWaypointIndex,
      totalWaypoints: _routePath.length,
    );

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('🎉 산책 완료!'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('소요 시간: ${_formatDuration(stats.duration)}'),
            Text('이동 거리: ${(stats.distance / 1000).toStringAsFixed(2)} km'),
            Text('예상 걸음 수: ${stats.steps} 걸음'),
            Text('경유지: ${stats.visitedWaypoints}/${stats.totalWaypoints}'),
            const SizedBox(height: 10),
            const Text('수고하셨습니다! 건강한 산책이었어요.'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              _stopWalking();
            },
            child: const Text('확인'),
          ),
        ],
      ),
    );
  }

  String _formatDuration(Duration duration) {
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    String twoDigitMinutes = twoDigits(duration.inMinutes.remainder(60));
    String twoDigitSeconds = twoDigits(duration.inSeconds.remainder(60));
    return '${twoDigits(duration.inHours)}:$twoDigitMinutes:$twoDigitSeconds';
  }

  void _clearAllMarkers() {
    setState(() {
      _smartMarkers.clear();
    });
    _updateMarkersOnMap();
  }

  Widget _buildWalkingControlPanel() {
    if (_walkingState == WalkingState.planning) return Container();

    return Positioned(
      bottom: 20,
      left: 20,
      right: 20,
      child: Card(
        color: Colors.black87,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                '🚶 산책 중',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  Column(
                    children: [
                      const Text('시간',
                          style: TextStyle(color: Colors.grey, fontSize: 12)),
                      Text(
                        _formatDuration(_walkingDuration),
                        style:
                            const TextStyle(color: Colors.white, fontSize: 14),
                      ),
                    ],
                  ),
                  Column(
                    children: [
                      const Text('거리',
                          style: TextStyle(color: Colors.grey, fontSize: 12)),
                      Text(
                        '${(_totalDistance / 1000).toStringAsFixed(2)} km',
                        style:
                            const TextStyle(color: Colors.white, fontSize: 14),
                      ),
                    ],
                  ),
                  Column(
                    children: [
                      const Text('걸음 수',
                          style: TextStyle(color: Colors.grey, fontSize: 12)),
                      Text(
                        '${(_totalDistance / 0.762).round()} 걸음',
                        style:
                            const TextStyle(color: Colors.white, fontSize: 14),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  ElevatedButton.icon(
                    icon: Icon(_walkingState == WalkingState.paused
                        ? Icons.play_arrow
                        : Icons.pause),
                    label: Text(
                        _walkingState == WalkingState.paused ? '재개' : '일시정지'),
                    onPressed: _toggleWalkingPause,
                    style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blueAccent),
                  ),
                  ElevatedButton.icon(
                    icon: const Icon(Icons.stop),
                    label: const Text('종료'),
                    onPressed: _stopWalking,
                    style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.redAccent),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('스마트 경로 산책하기'),
        actions: [
          IconButton(
            icon: const Icon(Icons.delete_forever),
            onPressed: _clearAllMarkers,
            tooltip: '모든 마커 삭제',
          ),
        ],
      ),
      body: Stack(
        children: [
          NaverMap(
            options: NaverMapViewOptions(
              initialCameraPosition: NCameraPosition(
                  target: _start ?? NLatLng(37.5665, 126.9780), zoom: 15),
              locationButtonEnable: true,
            ),
            onMapReady: (controller) {
              _mapController = controller;
              _updateMarkersOnMap();
            },
            onMapTapped: _onMapTapped,
          ),
          _buildWalkingControlPanel(),
        ],
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
      floatingActionButton: _walkingState == WalkingState.planning
          ? FloatingActionButton.extended(
              icon: const Icon(Icons.directions_walk),
              label: const Text('스마트 경로 추천받기'),
              onPressed: _requestSmartRoute,
            )
          : _walkingState == WalkingState.completed
              ? null
              : FloatingActionButton.extended(
                  icon: const Icon(Icons.flag),
                  label: const Text('산책 시작하기'),
                  onPressed: _startWalking,
                ),
    );
  }
}
