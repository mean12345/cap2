// route_with_stopover_page.dart
import 'package:flutter/material.dart';
import 'package:flutter_naver_map/flutter_naver_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'walking_tracking_page.dart';
import 'package:dangq/colors.dart';
import 'package:dangq/work/work_self/draggable_dst/draggable_dst.dart'; // 추가: MarkerManager가 있는 파일 import

class RouteWithStopoverPage extends StatefulWidget {
  final String? username; // nullable로 변경
  final int? dogId; // nullable로 변경
  final String? dogName; // nullable로 변경

  const RouteWithStopoverPage({
    super.key,
    this.username,
    this.dogId,
    this.dogName,
  });

  @override
  State<RouteWithStopoverPage> createState() => _RouteWithStopoverPageState();
}

class _RouteWithStopoverPageState extends State<RouteWithStopoverPage> {
  NaverMapController? _mapController;
  MarkerManager? _markerManager;
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
  String? profileImage;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _setCurrentLocation();
    _fetchDogProfiles();
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
        caption: NOverlayCaption(text: '출·도착'),
      );

      _endMarker = NMarker(
        id: 'end',
        position: _end!,
        iconTintColor: Colors.green,
        //caption: NOverlayCaption(text: '도착지'), 글씨가 겹쳐보여서 하나 지움
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

    await _mapController!.clearOverlays();

    // 기존 마커들과 함께 good/bad 마커도 표시
    await _markerManager?.loadMarkers();

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
    );

    // 마커 캡션 설정
    marker.setCaption(
        NOverlayCaption(text: '경유지 ${_stopoverMarkers.length + 1}'));

    // 마커 클릭 이벤트 추가
    marker.setOnTapListener((NMarker marker) {
      showDialog(
        context: context,
        builder: (BuildContext context) {
          return AlertDialog(
            title: const Text('경유지 삭제'),
            content: const Text('이 경유지를 삭제하시겠습니까?'),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('취소'),
              ),
              TextButton(
                onPressed: () {
                  Navigator.of(context).pop();
                  setState(() {
                    _stopoverMarkers
                        .removeWhere((m) => m.info.id == marker.info.id);
                    // 남은 경유지 마커들의 캡션 번호 재정렬
                    for (int i = 0; i < _stopoverMarkers.length; i++) {
                      _stopoverMarkers[i]
                          .setCaption(NOverlayCaption(text: '경유지 ${i + 1}'));
                    }
                  });
                  _updateMarkersOnMap();
                },
                child: const Text('삭제'),
              ),
            ],
          );
        },
      );
    });

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
    if (_stopoverMarkers.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('경유지를 선택해주세요'),
          duration: Duration(seconds: 2),
        ),
      );
      return;
    }

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
              routePath: path
                  .map((point) =>
                      NLatLng(point['lat'].toDouble(), point['lng'].toDouble()))
                  .toList(),
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

  Future<void> _moveToCurrentLocation() async {
    if (_mapController == null || _start == null) return;

    await _mapController!.updateCamera(
      NCameraUpdate.withParams(
        target: _start!,
        zoom: 15,
      ),
    );
  }

  Future<void> _fetchDogProfiles() async {
    setState(() {
      _isLoading = true;
    });

    final String baseUrl = dotenv.get('BASE_URL');

    try {
      final url = '$baseUrl/dogs/get_dogs?username=${widget.username}';
      final response = await http.get(Uri.parse(url));

      if (response.statusCode == 404) {
        setState(() {
          profileImage = null;
          _isLoading = false;
        });
        return;
      }

      if (response.statusCode == 200) {
        final List<dynamic> jsonResponse = json.decode(response.body);
        final dog = jsonResponse.firstWhere(
          (dog) => dog['id'] == widget.dogId,
          orElse: () => null,
        );

        setState(() {
          profileImage = dog != null ? dog['imageUrl'] as String? : null;
          _isLoading = false;
        });
      } else {
        setState(() {
          _isLoading = false;
        });
        throw Exception('Failed to load dog profiles');
      }
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      print('예외 발생: $e');
      rethrow;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        scrolledUnderElevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.of(context).pop(),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        actions: [
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
            onMapReady: (controller) async {
              _mapController = controller;
              _markerManager = MarkerManager(
                mapController: controller,
                username: widget.username ?? '',
                showDeleteConfirmationDialog: (markerName, markerId) {
                  // 마커 삭제 다이얼로그 구현
                  showDialog(
                    context: context,
                    builder: (BuildContext context) {
                      return AlertDialog(
                        title: const Text('마커 삭제'),
                        content: const Text('이 마커를 삭제하시겠습니까?'),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.of(context).pop(),
                            child: const Text('취소'),
                          ),
                          TextButton(
                            onPressed: () async {
                              await _markerManager
                                  ?.deleteMarkerFromDB(markerName);
                              await _mapController?.clearOverlays();
                              await _markerManager?.loadMarkers();
                              Navigator.of(context).pop();
                            },
                            child: const Text('삭제'),
                          ),
                        ],
                      );
                    },
                  );
                },
              );
              await _setCurrentLocation();
              await _markerManager?.loadMarkers();

              // 현재 위치로 카메라 이동 추가
              if (_start != null) {
                await controller.updateCamera(
                  NCameraUpdate.withParams(
                    target: _start!,
                    zoom: 15,
                    bearing: 0,
                    tilt: 0,
                  ),
                );
              }
            },
            onMapTapped: _onMapTapped,
            options: const NaverMapViewOptions(
              locationButtonEnable: false,
              indoorEnable: false,
              scaleBarEnable: false,
              initialCameraPosition: NCameraPosition(
                target: NLatLng(35.853488, 128.488708),
                zoom: 14,
              ),
            ),
          ),

          // 사용법 안내 (토글 가능)
          if (_showInstructions)
            Positioned(
              top: kToolbarHeight +
                  MediaQuery.of(context).padding.top +
                  80, // 정보 패널 아래로 조정
              right: 10,
              child: Card(
                color: AppColors.background,
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: const [
                      Text(
                        '사용법',
                        style: TextStyle(
                          color: Colors.black,
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                      ),
                      SizedBox(height: 4),
                      Text(
                        '• 지도 터치로 경유지 추가',
                        style: TextStyle(color: Colors.black, fontSize: 12),
                      ),
                      Text(
                        '• 초록색: 현재 위치',
                        style: TextStyle(color: Colors.black, fontSize: 12),
                      ),
                      Text(
                        '• 노란색: 경유지',
                        style: TextStyle(color: Colors.black, fontSize: 12),
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
                        /* 어떤 조건을 만족해야 나오는 코드인지 몰라서 일단 주석처리
                      children: [
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
                      ],*/
                        ),
                  ),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.olivegreen,
                      foregroundColor: Colors.black,
                      padding: const EdgeInsets.symmetric(vertical: 15),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(5),
                      ),
                    ),
                    onPressed: _requestRouteWithStopovers,
                    icon: const Icon(Icons.navigation),
                    label: Text(
                      _stopoverMarkers.isEmpty ? '경로 탐색' : '경유지 포함 경로 탐색',
                    ),
                  ),
                ),
              ],
            ),
          ),

          // 프로필 이미지와 도움말 아이콘
          Positioned(
            top: MediaQuery.of(context).size.height * 0.05,
            right: 16,
            child: Column(
              children: [
                Container(
                  width: 50,
                  height: 50,
                  decoration: BoxDecoration(
                    color: Colors.grey[300],
                    shape: BoxShape.circle,
                  ),
                  child: _isLoading
                      ? const CircularProgressIndicator()
                      : profileImage != null
                          ? ClipOval(
                              child: Image.network(
                                profileImage!,
                                fit: BoxFit.cover,
                              ),
                            )
                          : const Icon(
                              Icons.person,
                              color: Colors.white,
                              size: 30,
                            ),
                ),
                const SizedBox(height: 5),
                IconButton(
                  icon: Icon(
                    _showInstructions ? Icons.help : Icons.help_outline,
                    color: Colors.black,
                  ),
                  onPressed: () {
                    setState(() {
                      _showInstructions = !_showInstructions;
                    });
                  },
                  tooltip: '사용법',
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
