import 'package:flutter/material.dart';
import 'package:flutter_naver_map/flutter_naver_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'dart:async'; // for Timer
import 'package:dangq/work/work_self/draggable_dst/draggable_dst.dart'; // WorkDST 페이지 임포트

class RouteWithStopoverPage extends StatefulWidget {
  final String username;
  final int dogId;
  const RouteWithStopoverPage({
    super.key,
    required this.username,
    required this.dogId,
  });

  @override
  State<RouteWithStopoverPage> createState() => _RouteWithStopoverPageState();
}

class _RouteWithStopoverPageState extends State<RouteWithStopoverPage> {
  NaverMapController? _mapController;
  NLatLng? _start;
  NLatLng? _end;
  final List<NMarker> _stopoverMarkers = [];
  NMarker? _startMarker;
  NMarker? _endMarker;
  Position? currentPosition;

  // 경로 표시를 위한 변수들
  List<NLatLng> _routePath = [];
  NPolylineOverlay? _routePolyline;
  bool _isRouteVisible = false;

  Timer? _locationTimer;

  // 마커 선택 모드 추가
  String _selectionMode = 'none'; // 'none', 'start', 'end'

  // 역방향 경로 변수 추가
  NPolylineOverlay? _forwardRoutePolyline;
  NPolylineOverlay? _reverseRoutePolyline;
  List<NLatLng> _forwardPath = [];
  List<NLatLng> _reversePath = [];

  @override
  void initState() {
    super.initState();
    _initializeLocation();
  }

  @override
  void dispose() {
    _locationTimer?.cancel();
    super.dispose();
  }

  Future<void> _initializeLocation() async {
    try {
      if (!await Geolocator.isLocationServiceEnabled()) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('위치 서비스를 활성화해주세요.')),
        );
        return;
      }

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('위치 권한이 필요합니다.')),
          );
          return;
        }
      }

      await getCurrentLocation();
      if (currentPosition != null) {
        // 현재 위치를 출발지로 자동 설정
        _setStartLocation(
          NLatLng(currentPosition!.latitude, currentPosition!.longitude),
        );
      }

      // 주기적으로 위치 업데이트 (10초마다)
      _locationTimer = Timer.periodic(const Duration(seconds: 10), (_) {
        _updateCurrentLocation();
      });
    } catch (e) {
      print('위치 초기화 에러: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('위치를 가져오는데 실패했습니다.')),
      );
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

  Future<void> _updateCurrentLocation() async {
    try {
      await getCurrentLocation();
      if (currentPosition == null) return;

      if (_mapController != null) {
        await _mapController!.updateCamera(
          NCameraUpdate.withParams(
            target:
                NLatLng(currentPosition!.latitude, currentPosition!.longitude),
            zoom: 15,
          ),
        );
      }
    } catch (e) {
      print('위치 업데이트 에러: $e');
    }
  }

  // 지도 탭 이벤트 수정
  void _onMapTapped(NPoint point, NLatLng latLng) {
    switch (_selectionMode) {
      case 'start':
        _setStartLocation(latLng);
        break;
      case 'end':
        _setEndLocation(latLng);
        break;
    }
  }

  // 출발지 설정
  void _setStartLocation(NLatLng latLng) {
    print('출발지 설정: 위도=${latLng.latitude}, 경도=${latLng.longitude}');
    setState(() {
      _start = latLng;
      _startMarker = NMarker(
        id: 'start',
        position: latLng,
        iconTintColor: Colors.blue,
        caption: NOverlayCaption(text: '출발지'),
      );
      _selectionMode = 'none';
    });
    _updateMarkersOnMap();
  }

  // 도착지 설정
  void _setEndLocation(NLatLng latLng) {
    print('도착지 설정: 위도=${latLng.latitude}, 경도=${latLng.longitude}');
    setState(() {
      _end = latLng;
      _endMarker = NMarker(
        id: 'end',
        position: latLng,
        iconTintColor: Colors.green,
        caption: NOverlayCaption(text: '경유지'),
      );
      _selectionMode = 'none';
    });
    _updateMarkersOnMap();
  }

  // 현재 위치를 출발지로 설정하는 함수 추가
  void _setCurrentLocationAsStart() async {
    try {
      await getCurrentLocation();
      if (currentPosition == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('현재 위치를 가져올 수 없습니다')),
        );
        return;
      }

      _setStartLocation(
          NLatLng(currentPosition!.latitude, currentPosition!.longitude));
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('현재 위치 설정 실패')),
      );
    }
  }

  Future<void> _updateMarkersOnMap() async {
    if (_mapController == null) return;

    await _mapController!.clearOverlays();

    // 출발지 마커 추가
    if (_startMarker != null) {
      await _mapController!.addOverlay(_startMarker!);
    }

    // 도착지 마커 추가
    if (_endMarker != null) {
      await _mapController!.addOverlay(_endMarker!);
    }

    // 경로 polyline 다시 추가
    if (_routePolyline != null && _isRouteVisible) {
      await _mapController!.addOverlay(_routePolyline!);
    }
  }

  Future<void> _clearRoute() async {
    if (_mapController != null) {
      if (_forwardRoutePolyline != null) {
        await _mapController!.deleteOverlay(_forwardRoutePolyline!.info);
      }
      if (_reverseRoutePolyline != null) {
        await _mapController!.deleteOverlay(_reverseRoutePolyline!.info);
      }
    }

    setState(() {
      _forwardPath.clear();
      _reversePath.clear();
      _forwardRoutePolyline = null;
      _reverseRoutePolyline = null;
      _isRouteVisible = false;
    });
  }

  Future<void> _displayBothRoutes(
      List<dynamic> forwardPath, List<dynamic> reversePath) async {
    if (_mapController == null) return;

    await _clearRoute();

    // 정방향 경로
    final List<NLatLng> forwardPoints = forwardPath
        .map((point) =>
            NLatLng(point['lat'].toDouble(), point['lng'].toDouble()))
        .toList();

    // 역방향 경로
    final List<NLatLng> reversePoints = reversePath
        .map((point) =>
            NLatLng(point['lat'].toDouble(), point['lng'].toDouble()))
        .toList();

    // 시작점과 끝점 마커 추가
    if (forwardPoints.isNotEmpty) {
      final startMarker = NMarker(
        id: 'route_start',
        position: forwardPoints.first,
        iconTintColor: Colors.blue,
        caption: NOverlayCaption(
          text: '출발',
          color: Colors.blue,
          textSize: 14,
        ),
      );
      await _mapController!.addOverlay(startMarker);

      final endMarker = NMarker(
        id: 'route_end',
        position: forwardPoints.last,
        iconTintColor: Colors.red,
        caption: NOverlayCaption(
          text: '도착',
          color: Colors.red,
          textSize: 14,
        ),
      );
      await _mapController!.addOverlay(endMarker);
    }

    // 경로 표시
    // 정방향 폴리라인 (파란색)
    _forwardRoutePolyline = NPolylineOverlay(
      id: 'forward_route',
      coords: forwardPoints,
      color: Colors.blue,
      width: 5,
    );

    // 역방향 폴리라인 (빨간색)
    _reverseRoutePolyline = NPolylineOverlay(
      id: 'reverse_route',
      coords: reversePoints,
      color: Colors.blue,
      width: 5,
    );

    await _mapController!.addOverlay(_forwardRoutePolyline!);
    await _mapController!.addOverlay(_reverseRoutePolyline!);

    setState(() {
      _forwardPath = forwardPoints;
      _reversePath = reversePoints;
      _isRouteVisible = true;
    });
  }

  Future<void> _requestBothRoutes() async {
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

    final String baseUrl = dotenv.get('BASE_URL');
    final body = jsonEncode({
      'start': {'lat': _start!.latitude, 'lng': _start!.longitude},
      'end': {'lat': _end!.latitude, 'lng': _end!.longitude},
    });

    try {
      final responses = await Future.wait([
        http.post(
          Uri.parse('$baseUrl/direction/getPath'),
          headers: {'Content-Type': 'application/json'},
          body: body,
        ),
        http.post(
          Uri.parse('$baseUrl/direction/getReversePath'),
          headers: {'Content-Type': 'application/json'},
          body: body,
        ),
      ]);

      Navigator.of(context).pop(); // 로딩 다이얼로그 닫기

      if (responses[0].statusCode == 200 && responses[1].statusCode == 200) {
        final forwardPath = jsonDecode(responses[0].body)['path'] as List;
        final reversePath = jsonDecode(responses[1].body)['path'] as List;

        // 타입 안전한 변환 로직으로 수정
        final List<NLatLng> forwardPoints = List<NLatLng>.from(
          forwardPath.map((point) => NLatLng(
                (point['lat'] as num).toDouble(),
                (point['lng'] as num).toDouble(),
              )),
        );

        final List<NLatLng> reversePoints = List<NLatLng>.from(
          reversePath.map((point) => NLatLng(
                (point['lat'] as num).toDouble(),
                (point['lng'] as num).toDouble(),
              )),
        );

        // WorkDST로 이동하며 경로 전달
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => WorkDST(
              username: widget.username,
              dogId: widget.dogId,
              forwardPath: forwardPoints,
              reversePath: reversePoints,
            ),
          ),
        );
      } else {
        throw Exception('경로 요청 실패');
      }
    } catch (e) {
      Navigator.of(context).pop();
      print('HTTP 오류: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('경로 요청 중 오류 발생')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('경로 탐색'),
        backgroundColor: Colors.green,
        foregroundColor: Colors.white,
        actions: [
          // 현재 위치를 출발지로 설정하는 버튼 추가
          IconButton(
            icon: const Icon(Icons.my_location),
            onPressed: _setCurrentLocationAsStart,
            tooltip: '현재 위치를 출발지로 설정',
          ),
          IconButton(
            icon: Icon(
              Icons.place,
              color: _selectionMode == 'start' ? Colors.blue : Colors.blue,
              size: 28,
            ),
            onPressed: () {
              setState(() {
                _selectionMode = _selectionMode == 'start' ? 'none' : 'start';
              });
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('지도를 터치하여 출발지를 선택하세요'),
                  duration: Duration(seconds: 2),
                ),
              );
            },
            tooltip: '출발지 선택',
          ),
          // 도착지 설정 버튼
          IconButton(
            icon: Icon(Icons.location_on,
                color: _selectionMode == 'end' ? Colors.green : Colors.red),
            onPressed: () {
              setState(() {
                _selectionMode = _selectionMode == 'end' ? 'none' : 'end';
              });
            },
            tooltip: '도착지 설정',
          ),
        ],
      ),
      body: Stack(
        children: [
          NaverMap(
            options: const NaverMapViewOptions(
              locationButtonEnable: true,
              initialCameraPosition: NCameraPosition(
                target: NLatLng(35.853488, 128.488708),
                zoom: 14,
              ),
            ),
            onMapReady: (controller) {
              _mapController = controller;
              controller.setLocationTrackingMode(NLocationTrackingMode.follow);
              _updateMarkersOnMap();
            },
            onMapTapped: _onMapTapped,
          ),

          // 하단 버튼들
          Positioned(
            bottom: 20,
            left: 20,
            right: 20,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 15),
                    ),
                    onPressed: _requestBothRoutes,
                    icon: const Icon(Icons.navigation),
                    label: const Text('경로 추천'),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}