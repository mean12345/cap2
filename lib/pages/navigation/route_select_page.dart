// route_with_stopover_page.dart
import 'package:flutter/material.dart';
import 'package:flutter_naver_map/flutter_naver_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'walking_tracking_page.dart'; // 산책 추적 페이지 import

class RouteWithStopoverPage extends StatefulWidget {
  const RouteWithStopoverPage({super.key});

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

  // 경로 표시를 위한 변수들
  List<NLatLng> _routePath = [];
  NPolylineOverlay? _routePolyline;
  bool _isRouteVisible = false;
  
  // 사용법 표시 상태
  bool _showInstructions = false;

  @override
  void initState() {
    super.initState();
    _setCurrentLocation();
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
    });

    // 마커들을 지도에 추가
    if (_mapController != null) {
      _updateMarkersOnMap();
    }
  }

  void _onMapTapped(NPoint point, NLatLng latLng) {
    _addStopoverMarker(latLng);
  }

  Future<void> _updateMarkersOnMap() async {
    if (_mapController == null) return;

    // 기존 마커들 삭제
    await _mapController!.clearOverlays();

    // 출발지 마커 추가
    if (_startMarker != null) {
      await _mapController!.addOverlay(_startMarker!);
    }

    // 도착지 마커 추가
    if (_endMarker != null) {
      await _mapController!.addOverlay(_endMarker!);
    }

    // 경유지 마커들 추가
    for (final marker in _stopoverMarkers) {
      await _mapController!.addOverlay(marker);
    }

    // 경로 polyline 다시 추가
    if (_routePolyline != null && _isRouteVisible) {
      await _mapController!.addOverlay(_routePolyline!);
    }
  }

  void _addStopoverMarker(NLatLng latLng) {
    final id = 'stopover_${_stopoverMarkers.length}';
    final marker = NMarker(
      id: id,
      position: latLng,
      iconTintColor: Colors.yellow,
      caption: NOverlayCaption(text: '경유지 ${_stopoverMarkers.length + 1}'),
    );
    setState(() {
      _stopoverMarkers.add(marker);
    });

    // 마커를 지도에 추가
    _updateMarkersOnMap();
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

  Future<void> _displayRoute(List<dynamic> pathData) async {
    if (_mapController == null) return;

    // 기존 경로 삭제
    await _clearRoute();

    // 경로 데이터를 NLatLng 리스트로 변환
    final List<NLatLng> routePoints = pathData.map((point) {
      return NLatLng(point['lat'].toDouble(), point['lng'].toDouble());
    }).toList();

    // Polyline 생성
    final polyline = NPolylineOverlay(
      id: 'route_polyline',
      coords: routePoints,
      color: Colors.blue,
      width: 5,
    );

    // 지도에 polyline 추가
    await _mapController!.addOverlay(polyline);

    setState(() {
      _routePath = routePoints;
      _routePolyline = polyline;
      _isRouteVisible = true;
    });

    // 경로가 모두 보이도록 카메라 조정
    if (routePoints.isNotEmpty) {
      await _fitCameraToRoute(routePoints);
    }
  }

  Future<void> _fitCameraToRoute(List<NLatLng> points) async {
    if (_mapController == null || points.isEmpty) return;

    // 경로의 바운딩 박스 계산
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

    // 약간의 패딩 추가
    const double padding = 0.001;
    final NLatLngBounds bounds = NLatLngBounds(
      southWest: NLatLng(minLat - padding, minLng - padding),
      northEast: NLatLng(maxLat + padding, maxLng + padding),
    );

    // 카메라 이동
    await _mapController!.updateCamera(
        NCameraUpdate.fitBounds(bounds, padding: const EdgeInsets.all(50)));
  }

  Future<void> _requestRouteWithStopovers() async {
    if (_start == null || _end == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('출발지와 도착지가 설정되어야 합니다.')),
      );
      return;
    }

    // 로딩 표시
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(
        child: CircularProgressIndicator(),
      ),
    );

    final stopovers = _stopoverMarkers.map((m) {
      return {'lat': m.position.latitude, 'lng': m.position.longitude};
    }).toList();

    final body = jsonEncode({
      'start': {'lat': _start!.latitude, 'lng': _start!.longitude},
      'end': {'lat': _end!.latitude, 'lng': _end!.longitude},
      'stopovers': stopovers,
    });
    final String baseUrl = dotenv.get('BASE_URL');

    try {
      final response = await http.post(
        Uri.parse('$baseUrl/direction/getPath'),
        headers: {'Content-Type': 'application/json'},
        body: body,
      );

      // 로딩 다이얼로그 닫기
      Navigator.of(context).pop();

      if (response.statusCode == 200) {
        final decoded = jsonDecode(response.body);
        final List<dynamic> path = decoded['path'];

        // 산책 추적 페이지로 이동
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => WalkingTrackingPage(
              routePath: path.map((point) => 
                NLatLng(point['lat'].toDouble(), point['lng'].toDouble())
              ).toList(),
              stopovers: _stopoverMarkers.map((m) => m.position).toList(),
            ),
          ),
        );

      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('서버 오류: ${response.statusCode}')),
        );
      }
    } catch (e) {
      // 로딩 다이얼로그 닫기
      Navigator.of(context).pop();

      print('HTTP 오류: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('경로 요청 중 오류 발생')),
      );
    }
  }

  void _clearAllStopovers() {
    setState(() {
      _stopoverMarkers.clear();
    });
    _updateMarkersOnMap();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('경로 탐색'),
        backgroundColor: Colors.blue,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: Icon(_showInstructions ? Icons.help : Icons.help_outline),
            onPressed: () {
              setState(() {
                _showInstructions = !_showInstructions;
              });
            },
            tooltip: '사용법',
          ),
          if (_stopoverMarkers.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.clear_all),
              onPressed: _clearAllStopovers,
              tooltip: '경유지 모두 삭제',
            ),
          if (_isRouteVisible)
            IconButton(
              icon: const Icon(Icons.route_outlined),
              onPressed: _clearRoute,
              tooltip: '경로 숨기기',
            ),
        ],
      ),
      body: Stack(
        children: [
          NaverMap(
            onMapReady: (controller) {
              _mapController = controller;
              // 지도가 준비되면 마커들 추가
              _updateMarkersOnMap();
            }, 
            onMapTapped: _onMapTapped,
            options: const NaverMapViewOptions(
              locationButtonEnable: true,
              initialCameraPosition: NCameraPosition(
                target: NLatLng(35.853488, 128.488708),
                zoom: 14,
              ),
            ),
          ),

          // 정보 패널 (간소화)
          Positioned(
            top: 10,
            left: 10,
            right: 10,
            child: Card(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (_stopoverMarkers.isNotEmpty)
                      Text(
                        '경유지: ${_stopoverMarkers.length}개 선택',
                        style: const TextStyle(fontSize: 14, color: Colors.orange, fontWeight: FontWeight.bold),
                      ),
                    if (_isRouteVisible)
                      Text(
                        '경로가 표시되었습니다',
                        style: const TextStyle(fontSize: 12, color: Colors.purple),
                      ),
                  ],
                ),
              ),
            ),
          ),

          // 사용법 안내 (토글 가능)
          if (_showInstructions)
            Positioned(
              top: 80,
              right: 10,
              child: Card(
                color: Colors.black87,
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: const [
                      Text(
                        '사용법:',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                      ),
                      SizedBox(height: 4),
                      Text(
                        '• 지도 터치로 경유지 추가',
                        style: TextStyle(color: Colors.white, fontSize: 12),
                      ),
                      Text(
                        '• 초록색: 현재 위치',
                        style: TextStyle(color: Colors.green, fontSize: 12),
                      ),
                      Text(
                        '• 노란색: 경유지',
                        style: TextStyle(color: Colors.yellow, fontSize: 12),
                      ),
                    ],
                  ),
                ),
              ),
            ),

          // 하단 버튼들
          Positioned(
            bottom: 20,
            left: 20,
            right: 20,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (_stopoverMarkers.isNotEmpty || _isRouteVisible)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: Row(
                      children: [
                        if (_stopoverMarkers.isNotEmpty)
                          Expanded(
                            child: ElevatedButton.icon(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.orange,
                                foregroundColor: Colors.white,
                              ),
                              onPressed: _clearAllStopovers,
                              icon: const Icon(Icons.clear_all, size: 18),
                              label: const Text('경유지 삭제'),
                            ),
                          ),
                        if (_stopoverMarkers.isNotEmpty && _isRouteVisible)
                          const SizedBox(width: 10),
                        if (_isRouteVisible)
                          Expanded(
                            child: ElevatedButton.icon(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.red,
                                foregroundColor: Colors.white,
                              ),
                              onPressed: _clearRoute,
                              icon: const Icon(Icons.route_outlined, size: 18),
                              label: const Text('경로 삭제'),
                            ),
                          ),
                      ],
                    ),
                  ),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blue,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 15),
                    ),
                    onPressed: _requestRouteWithStopovers,
                    icon: const Icon(Icons.navigation),
                    label: Text(
                      _stopoverMarkers.isEmpty ? '경로 검색' : '경유지 포함 경로 검색',
                    ),
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