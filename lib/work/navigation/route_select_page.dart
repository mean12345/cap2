import 'package:dangq/colors.dart';
import 'package:flutter/material.dart';
import 'package:flutter_naver_map/flutter_naver_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'dart:async'; // for Timer
import 'package:dangq/work/work_self/work.dart'; // Work 페이지 임포트
import 'package:flutter/services.dart'; // 파일 상단에 추가

class RouteWithStopoverPage extends StatefulWidget {
  final String username;
  final int dogId;
  final String dogName;
  const RouteWithStopoverPage({
    super.key,
    required this.username,
    required this.dogId,
    required this.dogName,
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

  String? profileImage;
  bool _isLoading = false;

  // 마커 관리자 추가
  MarkerManager? _markerManager;
  bool _showMarkers = true;

  @override
  void initState() {
    super.initState();
    _initializeLocation();
    _fetchDogProfile();
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
        icon:
            NOverlayImage.fromAssetImage('assets/images/startingpoint_pin.png'),
        size: const Size(50, 60),
        anchor: const NPoint(0.5, 1.0),
        caption: const NOverlayCaption(
          text: '출발지',
          textSize: 14,
        ),
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
        icon: NOverlayImage.fromAssetImage('assets/images/waypoint_pin.png'),
        size: const Size(50, 60),
        anchor: const NPoint(0.5, 1.0),
        caption: const NOverlayCaption(
          text: '경유지',
          textSize: 14,
        ),
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

    // good/bad 마커 다시 로드
    if (_showMarkers) {
      await _markerManager?.loadMarkers();
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
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('출발지와 도착지를 모두 설정해주세요.'),
          duration: Duration(seconds: 2),
        ),
      );
      return;
    }

    if (!mounted) return;

    // 로딩 다이얼로그 표시
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(
        child: CircularProgressIndicator(),
      ),
    );

    try {
      final String baseUrl = dotenv.get('BASE_URL');
      final body = jsonEncode({
        'start': {'lat': _start!.latitude, 'lng': _start!.longitude},
        'end': {'lat': _end!.latitude, 'lng': _end!.longitude},
      });

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

      if (!mounted) return;

      // 로딩 다이얼로그 닫기
      Navigator.of(context).pop();

      if (responses[0].statusCode == 200 && responses[1].statusCode == 200) {
        final forwardPath = jsonDecode(responses[0].body)['path'] as List;
        final reversePath = jsonDecode(responses[1].body)['path'] as List;

        if (forwardPath.isEmpty || reversePath.isEmpty) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('경로를 찾을 수 없습니다. 다른 출발지나 도착지를 선택해주세요.'),
              duration: Duration(seconds: 2),
            ),
          );
          return;
        }

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

        // Work 페이지로 이동하며 경로 전달
        await Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => Work(
              username: widget.username,
              dogId: widget.dogId,
              dogName: widget.dogName,
              forwardPath: forwardPoints,
              reversePath: reversePoints,
            ),
          ),
        ).then((result) {
          // Work 페이지에서 돌아올 때 프로필 정보 업데이트
          if (result != null && result is Map<String, dynamic>) {
            Navigator.pop(context, {
              'dogId': result['dogId'],
              'dogName': result['dogName'],
              'imageUrl': result['imageUrl'],
            });
          }
        });
      } else {
        throw Exception(
            '경로 요청 실패: ${responses[0].statusCode}, ${responses[1].statusCode}');
      }
    } catch (e) {
      if (!mounted) return;

      // 로딩 다이얼로그 닫기
      Navigator.of(context).pop();

      // 오류 메시지 표시
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('경로 요청 중 오류가 발생했습니다: ${e.toString()}'),
          duration: const Duration(seconds: 2),
        ),
      );
      debugPrint('HTTP 오류: $e');
    }
  }

  Future<void> _fetchDogProfile() async {
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
        throw Exception('Failed to load dog profile');
      }
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      print('Error fetching dog profile: $e');
    }
  }

  // 마커 표시/숨김 토글 함수
  void _toggleMarkers() async {
    setState(() {
      _showMarkers = !_showMarkers;
    });

    // 마커 상태 업데이트
    await _mapController?.clearOverlays();

    // 마커가 켜져있을 때만 마커 표시
    if (_showMarkers) {
      await _markerManager?.loadMarkers();
    }

    // 출발지/도착지 마커와 경로 다시 추가
    if (_startMarker != null) {
      await _mapController?.addOverlay(_startMarker!);
    }
    if (_endMarker != null) {
      await _mapController?.addOverlay(_endMarker!);
    }
    if (_routePolyline != null && _isRouteVisible) {
      await _mapController?.addOverlay(_routePolyline!);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: PreferredSize(
        preferredSize:
            Size.fromHeight(MediaQuery.of(context).size.height * 0.08),
        child: Transform.translate(
          offset: const Offset(0, 6), // 3px만큼만 아래로 이동
          child: AppBar(
            systemOverlayStyle: const SystemUiOverlayStyle(
              statusBarColor: Colors.transparent, // 상태 표시줄 배경을 투명하게
              statusBarIconBrightness: Brightness.dark, // 상태 표시줄 아이콘을 어둡게
            ),
            backgroundColor: Colors.transparent,
            foregroundColor: Colors.black,
            elevation: 0,
          ),
        ),
      ),
      body: Stack(
        children: [
          NaverMap(
            options: const NaverMapViewOptions(
              locationButtonEnable: false,
              scaleBarEnable: false,
              initialCameraPosition: NCameraPosition(
                target: NLatLng(35.853488, 128.488708),
                zoom: 14,
              ),
            ),
            onMapReady: (controller) {
              _mapController = controller;
              controller.setLocationTrackingMode(NLocationTrackingMode.follow);

              // 마커 매니저 초기화
              _markerManager = MarkerManager(
                mapController: controller,
                username: widget.username,
                showDeleteConfirmationDialog: (_, __) {}, // 빈 함수로 대체
              );

              // 마커 로드
              _markerManager?.loadMarkers();

              _updateMarkersOnMap();
            },
            onMapTapped: _onMapTapped,
          ),

          // 마커 ON/OFF 버튼 추가
          Positioned(
            top: 100,
            right: 20,
            child: Transform.translate(
              offset: const Offset(3, 0),
              child: IconButton(
                onPressed: _toggleMarkers,
                icon: Icon(
                  Icons.place,
                  color: _showMarkers ? AppColors.green : Colors.grey,
                  size: 30,
                ),
              ),
            ),
          ),

          // 프로필 이미지 위젯 추가
          Positioned(
            top: MediaQuery.of(context).size.height * 0.05,
            right: 16,
            child: Container(
              width: 50,
              height: 50,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
              ),
              child: _isLoading
                  ? const CircularProgressIndicator()
                  : ClipOval(
                      child: profileImage != null
                          ? Image.network(
                              profileImage!,
                              fit: BoxFit.cover,
                            )
                          : Container(
                              color: Colors.grey[300],
                              child: const Icon(
                                Icons.pets,
                                color: Colors.grey,
                              ),
                            ),
                    ),
            ),
          ),

          //도착지, 경유지 지정하는 버튼
          Positioned(
            top: kToolbarHeight + 30,
            left: 20,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  icon: const Icon(Icons.my_location),
                  onPressed: () {
                    _setCurrentLocationAsStart(); // 현재 위치를 출발지로 설정하는 함수
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('출발지가 현재 위치로 변경되었습니다'),
                        duration: Duration(seconds: 2),
                      ),
                    );
                  },
                  tooltip: '현재 위치를 출발지로 설정',
                  style: IconButton.styleFrom(
                    backgroundColor: Colors.white.withOpacity(0.8),
                    padding: const EdgeInsets.all(12),
                  ),
                ),
                const SizedBox(height: 8),
                IconButton(
                  icon: Container(
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: const Color(0xFFFF6CCC),
                        width: 2,
                      ),
                    ),
                    child: Transform.rotate(
                      angle: -45 * 3.14159 / 180,
                      child: const Icon(
                        Icons.refresh,
                        color: Color(0xFFFF6CCC),
                        size: 28,
                      ),
                    ),
                  ),
                  onPressed: () {
                    setState(() {
                      _selectionMode =
                          _selectionMode == 'start' ? 'none' : 'start';
                    });
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('지도를 터치하여 출발지를 선택하세요'),
                        duration: Duration(seconds: 2),
                      ),
                    );
                  },
                  tooltip: '출발지 선택',
                  style: IconButton.styleFrom(
                    backgroundColor: Colors.white.withOpacity(0.8),
                    padding: const EdgeInsets.all(9),
                  ),
                ),
                const SizedBox(height: 8),
                IconButton(
                  icon: Container(
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: const Color(0xFF736D74),
                        width: 2,
                      ),
                    ),
                    child: const Icon(
                      Icons.add,
                      color: Color(0xFF736D74),
                      size: 28,
                    ),
                  ),
                  onPressed: () {
                    setState(() {
                      _selectionMode = _selectionMode == 'end' ? 'none' : 'end';
                    }); // 현재 위치를 출발지로 설정하는 함수
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('지도를 터치하여 경유지를 선택하세요'),
                        duration: Duration(seconds: 2),
                      ),
                    );
                  },
                  tooltip: '도착지 설정',
                  style: IconButton.styleFrom(
                    backgroundColor: Colors.white.withOpacity(0.8),
                    padding: const EdgeInsets.all(9),
                  ),
                ),
              ],
            ),
          ),

          // 하단 버튼
          Positioned(
            bottom: 30,
            left: 20,
            right: 20,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.olivegreen,
                      foregroundColor: Colors.black,
                      padding: const EdgeInsets.symmetric(vertical: 15),
                    ),
                    onPressed: _requestBothRoutes,
                    icon: const Icon(Icons.navigation),
                    label: const Text(
                      '산책 경로 추천',
                      style: TextStyle(
                        fontSize: 16, // 텍스트 크기 조정
                        fontWeight: FontWeight.w500, // 약간의 굵기 추가
                      ),
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

// 마커 관리 클래스 추가
class MarkerManager {
  final NaverMapController mapController;
  final String username;
  final Function(String, String) showDeleteConfirmationDialog;

  MarkerManager({
    required this.mapController,
    required this.username,
    required this.showDeleteConfirmationDialog,
  });

  Future<void> loadMarkers() async {
    try {
      debugPrint('마커 로드 시작');

      if (mapController == null) {
        debugPrint('MapController가 초기화되지 않았습니다.');
        return;
      }

      List<Map<String, dynamic>> markers = await fetchMarkersFromDB();
      debugPrint('DB에서 마커 불러오기 완료: ${markers.length}개 마커');

      if (markers.isEmpty) {
        debugPrint('로드할 마커가 없습니다.');
        return;
      }

      List<NMarker> markersToAdd = [];

      for (var marker in markers) {
        try {
          NLatLng position = NLatLng(
            double.parse(marker['latitude'].toString()),
            double.parse(marker['longitude'].toString()),
          );

          String markerType = marker['markerType'].toString();
          String markerName = marker['markerName'].toString();

          String imageAsset = markerType == 'bad'
              ? 'assets/images/dangerous_pin.png'
              : 'assets/images/good_pin.png';

          String markerText = markerType == 'bad' ? '위험한 곳' : '좋아하는 곳';
          Color textColor = markerType == 'bad'
              ? const Color(0xFFFF0000)
              : const Color(0xFF00FF00);

          final nMarker = NMarker(
            id: markerName,
            position: position,
            icon: NOverlayImage.fromAssetImage(imageAsset),
            size: Size(50.0, 60.0),
            caption: NOverlayCaption(
              text: markerText,
              color: textColor,
            ),
          );

          markersToAdd.add(nMarker);
          debugPrint('마커 준비 완료: $markerName (타입: $markerType)');
        } catch (e) {
          debugPrint('마커 생성 중 오류 발생: $e');
          continue;
        }
      }

      // 모든 마커를 한 번에 추가
      for (var marker in markersToAdd) {
        try {
          await mapController.addOverlay(marker);
          debugPrint('마커 추가 완료: ${marker.info.id}');
        } catch (e) {
          debugPrint('마커 추가 중 오류 발생: $e');
        }
      }

      debugPrint('총 ${markersToAdd.length}개의 마커 로드 완료');
    } catch (e) {
      debugPrint('마커 로드 중 오류 발생: $e');
    }
  }

  Future<List<Map<String, dynamic>>> fetchMarkersFromDB() async {
    final String baseUrl = dotenv.get('BASE_URL');

    try {
      final response = await http.get(Uri.parse('$baseUrl/markers/$username'));

      if (response.statusCode == 200) {
        Map<String, dynamic> data = jsonDecode(response.body);
        debugPrint('API에서 받은 마커 데이터: $data');

        List<dynamic> markersData = data['markers'];

        return markersData
            .map((item) => {
                  'latitude': item['latitude'],
                  'longitude': item['longitude'],
                  'markerType': item['marker_type'],
                  'markerName': item['marker_name'],
                })
            .toList();
      } else {
        debugPrint('Failed to fetch markers: ${response.body}');
        return [];
      }
    } catch (e) {
      debugPrint('Error fetching markers: $e');
      return [];
    }
  }
}
