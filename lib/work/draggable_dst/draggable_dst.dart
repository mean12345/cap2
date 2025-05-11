import 'package:flutter/material.dart';
import 'package:dangq/colors.dart';
import 'dart:math' as math;
import 'dart:async';
import 'package:flutter_naver_map/flutter_naver_map.dart';
import 'dart:developer';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:sensors_plus/sensors_plus.dart';
import 'package:geolocator/geolocator.dart';
import 'package:dangq/work/draggable_dst/timer_controller.dart';
import 'package:dangq/work/draggable_dst/format_utils.dart';
import 'package:dangq/work/check_place/selfplaceapp_popup.dart';

class WorkDST extends StatefulWidget {
  final String username;
  const WorkDST({super.key, required this.username});

  @override
  State<WorkDST> createState() => _WorkDSTState();
}

class _WorkDSTState extends State<WorkDST> {
  //TimerController 클래스의 객체를 생성하는 초기 설정
  final TimerController _timerController = TimerController();

  //드로어블 시트 위치 파악
  final DraggableScrollableController _draggableController =
      DraggableScrollableController();
  double _sheetPosition = 0.08;
  late NaverMapController _mapController;
  List<NLatLng> _path = [];
  double _totalDistance = 0.0;
  DateTime? _startTime;
  bool _isRecording = false;
  NLatLng? _lastPosition;
  Position? _currentPosition;

  // 정확한 걸음 수 측정을 위한 변수들
  int _stepCount = 0;
  List<double> _verticalAccelerationHistory = [];
  static const int _historySize = 15;
  static const double _stepThreshold = 2.0;
  static const double _stepCooldown = 0.4;
  DateTime? _lastStepTime;
  double _lastVerticalAcceleration = 0.0;

  @override
  void initState() {
    super.initState();
    _getCurrentLocation();
    loadMarkers();
  }

  @override
  void dispose() {
    _mapController.dispose();
    _timerController.dispose();
    _draggableController.dispose();
    super.dispose();
  }

  void _startStepCounting() {
    _verticalAccelerationHistory.clear();
    _stepCount = 0;

    userAccelerometerEvents.listen((UserAccelerometerEvent event) {
      if (!_isRecording) return;

      double xAcceleration = event.x;
      double yAcceleration = event.y;
      double zAcceleration = event.z;

      // 3D 벡터 크기 계산
      double accelerationMagnitude = math.sqrt(
        math.pow(xAcceleration, 2) +
            math.pow(yAcceleration, 2) +
            math.pow(zAcceleration, 2),
      );

      _verticalAccelerationHistory.add(accelerationMagnitude);
      if (_verticalAccelerationHistory.length > _historySize) {
        _verticalAccelerationHistory.removeAt(0);
      }

      if (_detectStep(accelerationMagnitude)) {
        final now = DateTime.now();
        if (_lastStepTime == null ||
            now.difference(_lastStepTime!).inMilliseconds >
                (_stepCooldown * 1000)) {
          setState(() {
            _stepCount++;
            _lastStepTime = now;
          });
        }
      }

      _lastVerticalAcceleration = accelerationMagnitude;
    });
  }

  bool _detectStep(double currentAcceleration) {
    if (_verticalAccelerationHistory.length < _historySize) return false;

    double mean = _verticalAccelerationHistory.reduce((a, b) => a + b) /
        _verticalAccelerationHistory.length;
    double variance = _verticalAccelerationHistory
            .map((x) => math.pow(x - mean, 2))
            .reduce((a, b) => a + b) /
        _verticalAccelerationHistory.length;

    // 성인의 초당 걸음수를 고려하여 간격 설정 (예: 1.2초당 한 걸음)
    bool isSignificantChange =
        (currentAcceleration - _lastVerticalAcceleration).abs() > 0.5;

    bool isTimePassed = _lastStepTime == null ||
        DateTime.now().difference(_lastStepTime!).inMilliseconds >
            1000; // 1초 이상 차이 (초당 걸음수 1로 가정)

    // 일정 시간이 지나고 가속도 변화가 일정 이상일 때만 걸음 증가
    return variance > _stepThreshold && isSignificantChange && isTimePassed;
  }

  Future<int> _saveMarkerToDB(String userName, double latitude,
      double longitude, String markerType, String markerName) async {
    final String baseUrl = dotenv.get('BASE_URL');

    try {
      final response = await http.post(
        Uri.parse('$baseUrl/markers'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'username': widget.username,
          'latitude': latitude,
          'longitude': longitude,
          'marker_type': markerType,
          'marker_name': markerName,
        }),
      );

      if (response.statusCode == 201) {
        debugPrint('Marker saved successfully!');
        return 1; // 성공 시 1 반환
      } else {
        debugPrint('Failed to save marker: ${response.body}');
        return -1; // 실패 시 -1 반환
      }
    } catch (e) {
      debugPrint('Error saving marker: $e');
      return -1; // 오류 발생 시 -1 반환
    }
  }

  void _markDangerousPlace(NLatLng currentPosition, String userName) async {
    // 현재 시간을 이용하여 고유한 marker_name 생성
    String markerName = 'marker_${DateTime.now().millisecondsSinceEpoch}';

    // 마커를 DB에 저장하는 코드
    int result = await _saveMarkerToDB(userName, currentPosition.latitude,
        currentPosition.longitude, 'bad', markerName);

    //위험한 곳 마커
    if (result == 1) {
      // DB에 저장 성공
      _mapController.addOverlay(
        NMarker(
          id: markerName, // 고유한 marker_name 사용
          position: currentPosition,
          icon: NOverlayImage.fromAssetImage('assets/images/dangerous_pin.png'),
          size: Size(50.0, 60.0),
          caption: NOverlayCaption(
            text: '위험한 곳',
            color: const Color(0xFFFF0000), // 캡션 텍스트 색상
          ),
        ),
      );
    }
  }

  void _markFavoritePlace(NLatLng currentPosition, String userName) async {
    // 현재 시간을 이용하여 고유한 marker_name 생성
    String markerName = 'marker_${DateTime.now().millisecondsSinceEpoch}';

    // 마커를 DB에 저장하는 코드 (예: API 호출)
    int result = await _saveMarkerToDB(userName, currentPosition.latitude,
        currentPosition.longitude, 'good', markerName);

    //좋아하는 곳 마커
    if (result == 1) {
      // DB에 저장 성공
      _mapController.addOverlay(
        NMarker(
          id: markerName, // 고유한 marker_name 사용
          position: currentPosition,
          icon: NOverlayImage.fromAssetImage('assets/images/good_pin.png'),
          size: Size(50.0, 60.0),
          caption: NOverlayCaption(
            text: '좋아하는 곳',
            color: const Color(0xFF00FF00),
          ),
        ),
      );
    }
  }

  Future<List<Map<String, dynamic>>> fetchMarkersFromDB() async {
    final String baseUrl = dotenv.get('BASE_URL');

    try {
      final response =
          await http.get(Uri.parse('$baseUrl/markers/${widget.username}'));

      if (response.statusCode == 200) {
        Map<String, dynamic> data = jsonDecode(response.body);
        debugPrint('API에서 받은 마커 데이터: $data'); // 마커 데이터 확인

        // 'markers' 배열을 가져와서 마커 정보 처리
        List<dynamic> markersData = data['markers'];

        return markersData
            .map((item) => {
                  'latitude': item['latitude'],
                  'longitude': item['longitude'],
                  'markerType': item['marker_type'],
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

  Future<void> _saveTrackData() async {
    if (_startTime == null || _path.isEmpty) return;

    final endTime = DateTime.now();
    final duration = endTime.difference(_startTime!);

    final durationInSeconds = duration.inSeconds > 0 ? duration.inSeconds : 1;

    final String baseUrl = dotenv.get('BASE_URL');

    try {
      final response = await http.post(
        Uri.parse('$baseUrl/tracking/saveTrack'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          'username': widget.username,
          'startTime': _startTime!.toIso8601String(),
          'endTime': endTime.toIso8601String(),
          'distance': _totalDistance.roundToDouble(),
          'stepCount': _stepCount,
        }),
      );

      if (response.statusCode == 200) {
        log('트랙 데이터 저장 성공');
        log('총 거리: $_totalDistance m');
        log('총 걸음 수: $_stepCount');
      } else {
        log('트랙 데이터 저장 실패: ${response.statusCode}');
      }
    } catch (e) {
      log('트랙 데이터 저장 중 오류: $e');
    }
  }

  void _startLocationTracking() async {
    // 위치 서비스 활성화 체크
    if (!await Geolocator.isLocationServiceEnabled()) return;

    // 위치 권한 확인
    if (await Geolocator.checkPermission() == LocationPermission.denied) {
      if (await Geolocator.requestPermission() ==
          LocationPermission.deniedForever) {
        return;
      }
    }

    // 첫 번째 위치 저장
    Position initialPosition = await Geolocator.getCurrentPosition(
      desiredAccuracy: LocationAccuracy.bestForNavigation,
    );
    _lastPosition =
        NLatLng(initialPosition.latitude, initialPosition.longitude);
    _path.add(_lastPosition!);

    // 10초마다 위치 업데이트
    Timer.periodic(Duration(seconds: 10), (timer) async {
      if (!_isRecording) {
        timer.cancel();
        return;
      }

      Position currentPosition = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.bestForNavigation,
      );
      NLatLng newLocation =
          NLatLng(currentPosition.latitude, currentPosition.longitude);

      // 이전 위치와의 이동 거리 계산
      if (_lastPosition != null) {
        double distance = Geolocator.distanceBetween(
          _lastPosition!.latitude,
          _lastPosition!.longitude,
          newLocation.latitude,
          newLocation.longitude,
        );

        // 이동 거리 업데이트
        setState(() {
          _totalDistance += distance; // 총 이동 거리 갱신
        });
        print("이동 거리: $_totalDistance");
      }

      setState(() {
        _path.add(newLocation); // 경로에 새 위치 추가
      });

      // 경로 오버레이 추가
      NPathOverlay pathOverlay = NPathOverlay(
        id: "test",
        coords: _path, // 경로의 좌표들
      );

      _mapController?.addOverlay(pathOverlay);

      _lastPosition = newLocation;
    });
  }

  double _calculateDistance(NLatLng start, NLatLng end) {
    const double earthRadius = 6371000;
    final double lat1 = start.latitude * (math.pi / 180);
    final double lat2 = end.latitude * (math.pi / 180);
    final double dLat = (end.latitude - start.latitude) * (math.pi / 180);
    final double dLon = (end.longitude - start.longitude) * (math.pi / 180);

    final double a = math.sin(dLat / 2) * math.sin(dLat / 2) +
        math.cos(lat1) *
            math.cos(lat2) *
            math.sin(dLon / 2) *
            math.sin(dLon / 2);
    final double c = 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
    final double distance = earthRadius * c;

    print("계산된 거리: $distance");

    return distance;
  }

  void _startRecording() {
    setState(() {
      _isRecording = true;
      _startTime = DateTime.now();
      _path.clear();
      _totalDistance = 0.0;
      _lastPosition = null;
      _stepCount = 0;

      _startLocationTracking();
      _startStepCounting();
    });
  }

  void _stopRecording() {
    if (!_isRecording) return;

    setState(() {
      _isRecording = false;
      _saveTrackData();
    });
  }

  Future<void> _getCurrentLocation() async {
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      // 위치 서비스가 비활성화되어 있으면 사용자에게 알림을 띄우거나 설정 페이지로 유도
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('위치 서비스가 비활성화되어 있습니다. 설정에서 위치 서비스를 활성화하세요.'),
      ));
      return;
    }

    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      // 권한이 거부된 경우, 사용자에게 권한을 요청하도록 유도
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('위치 권한이 거부되었습니다. 권한을 허용해야 위치를 사용할 수 있습니다.'),
        ));
        return;
      }
    }

    if (permission == LocationPermission.deniedForever) {
      // 권한이 영구적으로 거부된 경우
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('위치 권한이 영구적으로 거부되었습니다. 설정에서 권한을 변경해야 합니다.'),
      ));
      return;
    }

    try {
      _currentPosition = await Geolocator.getCurrentPosition(
          desiredAccuracy: LocationAccuracy.high);
      setState(() {
        // 위치 정보를 가져오면 UI 업데이트
      });
    } catch (e) {
      // 위치를 가져오는 데 실패한 경우 에러 처리
      print("Error getting location: $e");
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('위치를 가져오는 데 실패했습니다. 다시 시도해주세요.'),
      ));
    }
  }

  Future<String?> fetchMarkerName(double latitude, double longitude) async {
    final String baseUrl = dotenv.get('BASE_URL');
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/markers/getMarkerName'), // 서버의 URL로 수정
        headers: {
          'Content-Type': 'application/json',
        },
        body: json.encode({
          'latitude': latitude,
          'longitude': longitude,
        }),
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return data['marker_name']; // 서버에서 받은 marker_name
      } else {
        throw Exception('서버 오류: ${response.statusCode}');
      }
    } catch (e) {
      print('서버와의 통신 오류: $e');
      return null;
    }
  }

  Future<void> deleteMarkerFromDB(String markerName) async {
    final String baseUrl = dotenv.get('BASE_URL');

    try {
      final response = await http.delete(
        Uri.parse('$baseUrl/markers/$markerName'),
        headers: {'Content-Type': 'application/json'},
      );

      if (response.statusCode == 200) {
        debugPrint('Marker deleted successfully!');
      } else {
        debugPrint('Failed to delete marker: ${response.body}');
      }
    } catch (e) {
      debugPrint('Error deleting marker: $e');
    }
  }

  // 마커 클릭 처리를 위한 메서드 추가
  Future<void> handleMarkerClick(NMarker clickedMarker) async {
    try {
      double latitude = clickedMarker.position.latitude;
      double longitude = clickedMarker.position.longitude;

      debugPrint('[INFO] 클릭된 마커 정보 가져오기 시작');
      debugPrint('    위도: $latitude, 경도: $longitude');

      String? fetchedMarkerName = await fetchMarkerName(latitude, longitude);

      if (fetchedMarkerName != null) {
        debugPrint('[SUCCESS] 서버에서 marker_name 가져오기 성공');
        debugPrint('    받은 marker_name: $fetchedMarkerName');
        showDeleteConfirmationDialog(fetchedMarkerName, clickedMarker.info.id);
      } else {
        debugPrint('[ERROR] 서버에서 marker_name 가져오기 실패');
      }
    } catch (e) {
      debugPrint('[ERROR] 마커 클릭 이벤트 처리 중 오류 발생: $e');
    }
  }

  // 삭제 확인 다이얼로그 수정
  void showDeleteConfirmationDialog(String markerName, String markerId) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          backgroundColor: AppColors.background,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(5),
          ),
          title: const Text('마커 삭제'),
          content: const Text('이 마커를 삭제하시겠습니까?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              style: TextButton.styleFrom(foregroundColor: AppColors.green),
              child: const Text('취소'),
            ),
            TextButton(
              onPressed: () async {
                await deleteMarkerFromDB(markerName);
                await _mapController.clearOverlays();
                await loadMarkers();
                Navigator.of(context).pop();
              },
              style: TextButton.styleFrom(foregroundColor: AppColors.green),
              child: const Text('삭제'),
            ),
          ],
        );
      },
    );
  }

  Future<void> loadMarkers() async {
    try {
      debugPrint('마커 로드 시작');
      if (_mapController == null) {
        debugPrint('MapController가 초기화되지 않았습니다.');
        return;
      }

      await _mapController.clearOverlays();
      List<Map<String, dynamic>> markers = await fetchMarkersFromDB();
      debugPrint('DB에서 마커 불러오기 완료: ${markers.length}개 마커');

      for (var marker in markers) {
        NLatLng position = NLatLng(
          double.parse(marker['latitude'].toString()),
          double.parse(marker['longitude'].toString()),
        );

        String markerType = marker['markerType'].toString();
        String markerName = 'marker_${DateTime.now().millisecondsSinceEpoch}';

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

        nMarker.setOnTapListener((NMarker clickedMarker) async {
          try {
            double latitude = clickedMarker.position.latitude;
            double longitude = clickedMarker.position.longitude;

            String? fetchedMarkerName =
                await fetchMarkerName(latitude, longitude);
            if (fetchedMarkerName != null) {
              showDeleteConfirmationDialog(
                  fetchedMarkerName, clickedMarker.info.id);
            }
          } catch (e) {
            debugPrint('마커 클릭 처리 중 오류: $e');
          }
        });

        await _mapController.addOverlay(nMarker);
        debugPrint('마커 추가 완료: $markerName (타입: $markerType)');
      }

      debugPrint('총 ${markers.length}개의 마커 로드 완료');
    } catch (e) {
      debugPrint('마커 로드 중 오류 발생: $e');
    }
  }

// 스크롤에 있는 끌어 올리는 바
  Widget dragHandleDST() {
    return Container(
      height: 3.0,
      width: 30.0,
      decoration: BoxDecoration(
        color: AppColors.workDSTGray,
        borderRadius: BorderRadius.circular(2.0), // 모서리를 둥글게
      ),
    );
  }

// 스크롤 상단 걸음수, 시간
  Widget draggableDSTTop() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        Expanded(child: textBoxDST('걸음수', '걸음')),
        verticalLineDST(),
        Expanded(child: textBoxDST('시간', 's')),
        verticalLineDST(),
        Expanded(child: textBoxDST('이동거리', 'm')),
      ],
    );
  }

// 걸음수, 시간 입력받아 정해진 형식으로 표시
  Widget textBoxDST(String label, String type) {
    return Column(
      children: [
        Text(label, style: const TextStyle(color: Colors.black)),
        ValueListenableBuilder<int>(
          valueListenable: _timerController,
          builder: (context, time, child) {
            String displayValue = '';
            switch (type) {
              case '걸음':
                // 걸음 수 표시
                displayValue = _stepCount.toString();
                break;
              case 's':
                // 시간 표시
                displayValue = FormatUtils.formatTime(time);
                break;
              case 'm':
                // 거리 표시
                displayValue = _totalDistance.toStringAsFixed(1) + 'm';
                break;
            }
            return Text(displayValue,
                style: const TextStyle(color: Colors.black));
          },
        ),
      ],
    );
  }

// 스크롤 상단의 각 칸을 구분하는 세로 선
  Widget verticalLineDST() {
    return Container(
      width: 1,
      height: 75,
      color: AppColors.lightgreen,
    );
  }

// 상단과 하단을 나누는 수평 구분선
  Widget topBottomLine() {
    return Container(
      height: 1.0,
      width: 460.0,
      color: AppColors.lightgreen,
    );
  }

  Widget draggableDSTBottom() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // 시작 버튼
          AnimatedOpacity(
            duration: const Duration(milliseconds: 200),
            opacity: _timerController.isRunning ? 0.5 : 1.0,
            child: ElevatedButton(
              onPressed: _timerController.isRunning
                  ? null
                  : () {
                      _startRecording();
                      _timerController.startTimer();
                    },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF79B883),
                foregroundColor: Colors.white,
                elevation: 0,
                padding:
                    const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.play_arrow_rounded,
                    size: 20,
                    color: _timerController.isRunning
                        ? Colors.grey[400]
                        : Colors.white,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    '시작',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: _timerController.isRunning
                          ? Colors.grey[400]
                          : Colors.white,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(width: 24), // 버튼 사이 간격 증가
          // 중지 버튼
          ElevatedButton(
            onPressed: _timerController.isRunning
                ? () {
                    _timerController.resetTimer();
                    _stopRecording();
                  }
                : null,
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFFF6B6B),
              foregroundColor: Colors.white,
              elevation: 0,
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.stop_rounded,
                  size: 20,
                  color: _timerController.isRunning
                      ? Colors.white
                      : Colors.grey[400],
                ),
                const SizedBox(width: 6),
                Text(
                  '중지',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: _timerController.isRunning
                        ? Colors.white
                        : Colors.grey[400],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_currentPosition == null) {
      return Center(child: CircularProgressIndicator());
    } else {
      debugPrint('Current Position: $_currentPosition');
    }

    //시트의 화면 상단에서의 위치 계산
    final sheetPixelPosition =
        MediaQuery.of(context).size.height * _sheetPosition;

    return Stack(
      children: [
        // NaverMap 위젯
        NaverMap(
          onMapReady: (controller) {
            _mapController = controller;
            loadMarkers();
            controller.setLocationTrackingMode(NLocationTrackingMode.follow);
          },
          options: NaverMapViewOptions(
            locationButtonEnable: false, // 유저 위치 버튼 비활성화
            initialCameraPosition: NCameraPosition(
              target: const NLatLng(37.5666102, 126.9783881),
              zoom: 15,
            ),
          ),
        ),
        // 위험 장소 버튼
        Positioned(
          left: 20,
          bottom: sheetPixelPosition + 10,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ElevatedButton(
                  onPressed: () {
                    print("위험 장소 클릭");
                    if (_currentPosition != null) {
                      NLatLng currentLatLng = NLatLng(
                          _currentPosition!.latitude,
                          _currentPosition!.longitude);
                      print(
                          "위험 장소의 현재 위치: ${currentLatLng.latitude}, ${currentLatLng.longitude}");
                      _markDangerousPlace(currentLatLng, widget.username);
                    } else {
                      print("현재 위치가 null입니다.");
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    padding: EdgeInsets.zero,
                    shape: CircleBorder(),
                    backgroundColor: Colors.white,
                  ),
                  child: Container(
                    width: 60,
                    height: 60,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.transparent, // 배경은 투명
                    ),
                    child: Icon(
                      Icons.error_outline,
                      color: Colors.red,
                      size: 52,
                    ),
                  )),
              const SizedBox(height: 16),
              ElevatedButton(
                  onPressed: () {
                    print("최애 장소 클릭 시작");
                    if (_currentPosition != null) {
                      NLatLng currentLatLng = NLatLng(
                          _currentPosition!.latitude,
                          _currentPosition!.longitude);
                      print(
                          "최애 장소의 현재 위치: ${currentLatLng.latitude}, ${currentLatLng.longitude}");
                      _markFavoritePlace(currentLatLng, widget.username);
                    } else {
                      print("현재 위치가 null입니다.");
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    padding: EdgeInsets.zero,
                    shape: CircleBorder(),
                    backgroundColor: Colors.white,
                  ),
                  child: Container(
                    width: 60,
                    height: 60,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.transparent, // 배경은 투명
                    ),
                    child: Icon(
                      Icons.check_circle_outline,
                      color: Colors.green,
                      size: 52,
                    ),
                  )),
            ],
          ),
        ),
        // 장소 직접 추가 버튼
        Positioned(
          right: 20,
          bottom: sheetPixelPosition + 10,
          child: GestureDetector(
            onTap: () {
              showDialog(
                context: context,
                builder: (BuildContext context) {
                  return AddPlaceDialog(username: widget.username);
                },
              );
            },
            child: Container(
              width: 60,
              height: 60,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black26,
                    blurRadius: 4,
                    offset: Offset(0, 2),
                  ),
                ],
              ),
              child: Icon(
                Icons.add,
                color: Colors.black,
                size: 52,
              ),
            ),
          ),
        ),
        // 드로어블 시트
        NotificationListener<DraggableScrollableNotification>(
          onNotification: (notification) {
            setState(() {
              _sheetPosition = notification.extent;
            });
            return true;
          },
          child: DraggableScrollableSheet(
            controller: _draggableController,
            initialChildSize: 0.07,
            minChildSize: 0.07,
            maxChildSize: 0.4,
            builder: (context, controller) {
              return Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  border: Border(
                    top: BorderSide(
                      color: Color(0xFFB6B6B6),
                      width: 2.0,
                    ),
                    left: BorderSide(
                      color: Color(0xFFB6B6B6),
                      width: 2.0,
                    ),
                    right: BorderSide(
                      color: Color(0xFFB6B6B6),
                      width: 2.0,
                    ),
                  ),
                  borderRadius:
                      const BorderRadius.vertical(top: Radius.circular(20)),
                ),
                child: SingleChildScrollView(
                  controller: controller,
                  child: Padding(
                    padding: const EdgeInsets.all(10),
                    child: Column(
                      children: [
                        SizedBox(height: 10),
                        dragHandleDST(),
                        SizedBox(height: 40),
                        Column(
                          children: [
                            draggableDSTTop(),
                            SizedBox(height: 20),
                            topBottomLine(),
                            SizedBox(height: 20),
                            draggableDSTBottom(),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}
