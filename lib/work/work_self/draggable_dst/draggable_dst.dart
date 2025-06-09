import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:dangq/colors.dart';
import 'dart:math' as math;
import 'dart:async';
import 'package:geolocator/geolocator.dart';
import 'package:flutter_naver_map/flutter_naver_map.dart';
import 'dart:developer';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:sensors_plus/sensors_plus.dart';
import 'package:geolocator/geolocator.dart';
import 'package:dangq/work/work_self/draggable_dst/timer_controller.dart';
import 'package:dangq/work/work_self/draggable_dst/format_utils.dart';
import 'package:dangq/work/check_place/selfplaceapp_popup.dart';
import 'package:dangq/work/work_self/draggable_dst/speed_tracker.dart';
//산책 페이지의 끌어 올리는 부분과 네이버 맵
import 'dart:math';

class WorkDST extends StatefulWidget {
  final String username;
  final int dogId;
  final List<NLatLng>? forwardPath;
  final List<NLatLng>? reversePath;

  const WorkDST({
    super.key,
    required this.username,
    required this.dogId,
    this.forwardPath,
    this.reversePath,
  });

  @override
  State<WorkDST> createState() => _WorkDSTState();
}

class _WorkDSTState extends State<WorkDST> {
  final TimerController _timerController = TimerController();
  final DraggableScrollableController _draggableController =
      DraggableScrollableController();

  late NaverMapController _mapController;
  MarkerManager? _markerManager;
  LocationTracker? _locationTracker;
  late SpeedTracker _speedTracker;

  double _sheetPosition = 0.08;
  bool _isRecording = false;

  // 경로 표시를 위한 변수 추가
  List<NLatLng>? _forwardPath;
  List<NLatLng>? _reversePath;
  NPolylineOverlay? _forwardRouteOverlay;
  NPolylineOverlay? _reverseRouteOverlay;

  bool _showMarkers = true; // 마커 표시 상태 변수 추가

  @override
  void initState() {
    super.initState();
    _speedTracker = SpeedTracker(
      onSpeedUpdate: (speed) => setState(() {}),
    );

    // 경로 데이터 디버그
    debugPrint('전달받은 경로 데이터:');
    debugPrint('정방향 경로: ${widget.forwardPath?.length ?? 0}개 좌표');
    debugPrint('역방향 경로: ${widget.reversePath?.length ?? 0}개 좌표');
    if (widget.forwardPath != null) {
      debugPrint(
          '첫 좌표: ${widget.forwardPath!.first.latitude}, ${widget.forwardPath!.first.longitude}');
      debugPrint(
          '마지막 좌표: ${widget.forwardPath!.last.latitude}, ${widget.forwardPath!.last.longitude}');
    }

    // 전달받은 경로 저장
    _forwardPath = widget.forwardPath;
    _reversePath = widget.reversePath;
  }

  //마커 크기
  double m_width = 50;
  double m_height = 144;

  @override
  void dispose() {
    _mapController.dispose();
    _timerController.dispose();
    _draggableController.dispose();
    super.dispose();
  }

  //마커 삭제 확인 다이얼로그
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
                await _markerManager?.deleteMarkerFromDB(markerName);
                await _mapController.clearOverlays(); // 모든 마커 clear
                await _markerManager?.loadMarkers(); // 전체 마커 다시 불러오기
                setState(() {}); // UI 갱신
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

  //시작과 정지 버튼
  void _startRecording() {
    setState(() {
      _isRecording = true;
    });
    _locationTracker?.startRecording();
    _speedTracker.startTracking();
    _timerController.startTimer();
  }

  //정지 버튼
  void _stopRecording() {
    if (!_isRecording) return;
    setState(() {
      _isRecording = false;
    });
    _locationTracker?.stopRecording();
    _speedTracker.stopTracking();
    _timerController.resetTimer();
    _locationTracker?.saveTrackData();
  }

  // 경로 표시 함수
  Future<void> displayRoutes(
      List<NLatLng> forwardPath, List<NLatLng> reversePath) async {
    if (_mapController == null) return;

    try {
      // 기존 오버레이 삭제 전에 존재 여부 확인
      if (_forwardRouteOverlay != null) {
        try {
          await _mapController.deleteOverlay(_forwardRouteOverlay!.info);
        } catch (e) {
          debugPrint('정방향 경로 삭제 실패: $e');
        }
      }
      if (_reverseRouteOverlay != null) {
        try {
          await _mapController.deleteOverlay(_reverseRouteOverlay!.info);
        } catch (e) {
          debugPrint('역방향 경로 삭제 실패: $e');
        }
      }

      // 시작점과 끝점 마커 추가
      if (forwardPath.isNotEmpty) {
        // 출발지 마커
        final startMarker = NMarker(
          id: 'route_start',
          position: forwardPath.first,
          icon: NOverlayImage.fromAssetImage(
              'assets/images/startingpoint_pin.png'),
          size: const Size(50, 60),
          anchor: const NPoint(0.5, 1.0),
          caption: const NOverlayCaption(
            text: '출발지',
            textSize: 14,
          ),
        );
        await _mapController.addOverlay(startMarker);

        // 도착지 마커
        final endMarker = NMarker(
          id: 'route_end',
          position: forwardPath.last,
          icon: NOverlayImage.fromAssetImage('assets/images/waypoint_pin.png'),
          size: const Size(50, 60),
          anchor: const NPoint(0.5, 1.0),
          caption: const NOverlayCaption(
            text: '경유지',
            textSize: 14,
          ),
        );
        await _mapController.addOverlay(endMarker);
      }

      // 새로운 오버레이 생성 및 추가
      _forwardRouteOverlay = NPolylineOverlay(
        id: 'forward_route_${DateTime.now().millisecondsSinceEpoch}', // 고유 ID 사용
        coords: forwardPath,
        color: AppColors.green,
        width: 5,
      );

      _reverseRouteOverlay = NPolylineOverlay(
        id: 'reverse_route_${DateTime.now().millisecondsSinceEpoch}', // 고유 ID 사용
        coords: reversePath,
        color: AppColors.green,
        width: 5,
      );

      // 오버레이 추가
      await _mapController.addOverlay(_forwardRouteOverlay!);
      await _mapController.addOverlay(_reverseRouteOverlay!);

      setState(() {
        _forwardPath = forwardPath;
        _reversePath = reversePath;
      });

      // 경로가 모두 보이도록 카메라 위치 조정
      final allPoints = [...forwardPath, ...reversePath];
      if (allPoints.isNotEmpty) {
        double minLat = allPoints.map((p) => p.latitude).reduce(min);
        double maxLat = allPoints.map((p) => p.latitude).reduce(max);
        double minLng = allPoints.map((p) => p.longitude).reduce(min);
        double maxLng = allPoints.map((p) => p.longitude).reduce(max);

        final bounds = NLatLngBounds(
          southWest: NLatLng(minLat - 0.001, minLng - 0.001),
          northEast: NLatLng(maxLat + 0.001, maxLng + 0.001),
        );

        await _mapController.updateCamera(
          NCameraUpdate.fitBounds(
            bounds,
            padding: const EdgeInsets.all(50),
          ),
        );
      }
    } catch (e) {
      debugPrint('경로 표시 중 오류 발생: $e');
    }
  }

  // 마커 표시/숨김 토글 함수
  void _toggleMarkers() async {
    setState(() {
      _showMarkers = !_showMarkers;
    });

    // 마커 상태 업데이트
    await _mapController.clearOverlays();

    // 마커가 켜져있을 때만 마커 표시
    if (_showMarkers) {
      await _markerManager?.loadMarkers();
    }

    // 경로는 항상 다시 표시
    if (_forwardPath != null && _reversePath != null) {
      await displayRoutes(_forwardPath!, _reversePath!);
    }
  }

  @override
  Widget build(BuildContext context) {
    final sheetPixelPosition =
        MediaQuery.of(context).size.height * _sheetPosition;

    return Stack(
      children: [
        //네이버 지도
        NaverMap(
          onMapReady: (controller) async {
            controller.setLocationTrackingMode(NLocationTrackingMode.follow);
            _mapController = controller;
            _markerManager = MarkerManager(
              mapController: controller,
              username: widget.username,
              showDeleteConfirmationDialog: showDeleteConfirmationDialog,
            );

            _locationTracker = LocationTracker(
              mapController: controller,
              username: widget.username,
              dogId: widget.dogId,
              onDistanceUpdate: (distance) {
                setState(() {});
                if (_locationTracker?.currentPosition != null) {
                  _speedTracker.updateSpeed(_locationTracker!.currentPosition!);
                }
              },
            );

            // 경로가 있으면 표시
            if (_forwardPath != null && _reversePath != null) {
              await displayRoutes(_forwardPath!, _reversePath!);
            }

            // 마커 로드
            await _markerManager?.loadMarkers();
            await _mapController.clearOverlays();
            await _markerManager?.loadMarkers();

            // 경로 다시 표시 (마커가 경로를 가리지 않도록)
            if (_forwardPath != null && _reversePath != null) {
              await displayRoutes(_forwardPath!, _reversePath!);
            }

            controller.setLocationTrackingMode(NLocationTrackingMode.follow);
          },
          /* 지도 누르는 곳에 good 마커 생성
          onMapTapped: (NPoint point, NLatLng latLng) async {
            try {
              await _markerManager
                  ?.markFavoritePlace(latLng); //markFavoritePlace
              debugPrint('위험 마커 생성: ${latLng.latitude}, ${latLng.longitude}');
            } catch (e) {
              debugPrint('마커 생성 중 오류: $e');
            }
          },*/
          options: NaverMapViewOptions(
            locationButtonEnable: false,
            initialCameraPosition: NCameraPosition(
              target: const NLatLng(37.5666102, 126.9783881),
              zoom: 15,
            ),
          ),
        ),

        //마커
        Positioned(
          right: 20,
          bottom: sheetPixelPosition + 10,
          child: Container(
            width: m_width,
            height: m_height,
            child: Stack(
              alignment: Alignment.center,
              children: [
                // 원통 하단
                Positioned(
                  bottom: 0,
                  child: Container(
                    width: m_width,
                    height: m_height / 3,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      border: Border(
                        top: BorderSide(color: Colors.grey.shade300, width: 1),
                      ),
                      borderRadius: BorderRadius.vertical(
                        bottom: Radius.circular(m_width / 2),
                      ),
                    ),
                  ),
                ),
                // 원통 본체
                Positioned(
                  top: m_height / 3,
                  child: Container(
                    width: m_width,
                    height: m_height / 3,
                    color: Colors.white,
                  ),
                ),
                // 원통 상단
                Positioned(
                  top: 0,
                  child: Container(
                    width: m_width,
                    height: m_height / 3,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      border: Border(
                        bottom:
                            BorderSide(color: Colors.grey.shade300, width: 1),
                      ),
                      borderRadius: BorderRadius.vertical(
                        top: Radius.circular(m_width / 2),
                      ),
                    ),
                  ),
                ),
                // 위험 장소 아이콘
                Positioned(
                  top: (m_height / 6) - 17.5,
                  child: GestureDetector(
                    onTap: () async {
                      try {
                        await _locationTracker?.getCurrentLocation();
                        if (_locationTracker?.currentPosition != null) {
                          NLatLng currentLatLng = NLatLng(
                            _locationTracker!.currentPosition!.latitude,
                            _locationTracker!.currentPosition!.longitude,
                          );
                          await _markerManager
                              ?.markDangerousPlace(currentLatLng);
                          debugPrint(
                              'Dangerous place marker created at: ${currentLatLng.latitude}, ${currentLatLng.longitude}');
                        } else {
                          debugPrint('Current position is null');
                        }
                      } catch (e) {
                        debugPrint('Error creating dangerous place marker: $e');
                      }
                    },
                    child: Icon(
                      Icons.warning_amber_rounded,
                      color: Colors.red,
                      size: 35,
                    ),
                  ),
                ),
                // 즐겨찾기 아이콘
                Positioned(
                  top: (m_height / 2) - 17.5,
                  child: GestureDetector(
                    onTap: () async {
                      try {
                        await _locationTracker?.getCurrentLocation();
                        if (_locationTracker?.currentPosition != null) {
                          NLatLng currentLatLng = NLatLng(
                            _locationTracker!.currentPosition!.latitude,
                            _locationTracker!.currentPosition!.longitude,
                          );
                          await _markerManager
                              ?.markFavoritePlace(currentLatLng);
                          debugPrint(
                              'Favorite place marker created at: ${currentLatLng.latitude}, ${currentLatLng.longitude}');
                        } else {
                          debugPrint('Current position is null');
                        }
                      } catch (e) {
                        debugPrint('Error creating favorite place marker: $e');
                      }
                    },
                    child: Icon(
                      Icons.thumb_up_off_alt,
                      color: const Color(0xFF16DB00),
                      size: 35,
                    ),
                  ),
                ),
                // 장소 추가 아이콘
                Positioned(
                  bottom: (m_height / 6) - 17.5,
                  child: GestureDetector(
                    onTap: () {
                      showDialog(
                        context: context,
                        builder: (BuildContext context) {
                          return AddPlaceDialog(
                            username: widget.username,
                            onMarkerAdded: (markerName, latitude, longitude,
                                markerType) async {
                              String imageAsset = markerType == 'bad'
                                  ? 'assets/images/dangerous_pin.png'
                                  : 'assets/images/good_pin.png';
                              String markerText =
                                  markerType == 'bad' ? '위험한 곳' : '좋아하는 곳';
                              Color textColor = markerType == 'bad'
                                  ? const Color(0xFFFF0000)
                                  : const Color(0xFF00FF00);

                              final marker = NMarker(
                                id: markerName,
                                position: NLatLng(latitude, longitude),
                                icon: NOverlayImage.fromAssetImage(imageAsset),
                                size: Size(50.0, 60.0),
                                caption: NOverlayCaption(
                                  text: markerText,
                                  color: textColor,
                                ),
                              );

                              marker.setOnTapListener(
                                  (NMarker clickedMarker) async {
                                try {
                                  showDeleteConfirmationDialog(
                                      markerName, clickedMarker.info.id);
                                } catch (e) {
                                  debugPrint('마커 클릭 처리 중 오류: $e');
                                }
                              });

                              await _mapController.addOverlay(marker);
                            },
                          );
                        },
                      );
                    },
                    child: Icon(
                      Icons.add_circle_outline,
                      color: Colors.black,
                      size: 35,
                    ),
                  ),
                ),
              ],
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
            // 드로어블 시트의 높이 조절
            initialChildSize: 0.07,
            minChildSize: 0.07,
            maxChildSize: 0.4,
            builder: (context, controller) {
              return Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius:
                      const BorderRadius.vertical(top: Radius.circular(20)),
                ),
                child: SingleChildScrollView(
                  controller: controller,
                  child: Padding(
                    padding: const EdgeInsets.all(0),
                    child: Column(
                      children: [
                        SizedBox(height: 20),
                        DraggableSheetWidgets.dragHandle(), // 드래그 핸들
                        SizedBox(height: 40),
                        Column(
                          children: [
                            DraggableSheetWidgets.topSection(
                              //산책 정보
                              speed: _speedTracker.currentSpeed,
                              timerController: _timerController,
                              totalDistance:
                                  _locationTracker?.totalDistance ?? 0.0,
                            ),
                            DraggableSheetWidgets.horizontalLine(), //상단 하단 구분선
                            SizedBox(height: 20),
                            DraggableSheetWidgets.bottomSection(
                              //시작 정지 버튼
                              isRunning: _isRecording,
                              onStartPressed: _startRecording,
                              onStopPressed: _stopRecording,
                            ),
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
      ],
    );
  }
}

// 여기서부터 마커 관련 코드

class MarkerManager {
  final NaverMapController mapController;
  final String username;
  final Function(String, String) showDeleteConfirmationDialog;

  MarkerManager({
    required this.mapController,
    required this.username,
    required this.showDeleteConfirmationDialog,
  });

  Future<int> _saveMarkerToDB(String userName, double latitude,
      double longitude, String markerType, String markerName) async {
    final String baseUrl = dotenv.get('BASE_URL');

    try {
      final response = await http.post(
        Uri.parse('$baseUrl/markers'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'username': userName,
          'latitude': latitude,
          'longitude': longitude,
          'marker_type': markerType,
          'marker_name': markerName,
        }),
      );

      if (response.statusCode == 201) {
        debugPrint('Marker saved successfully!');
        return 1;
      } else {
        debugPrint('Failed to save marker: ${response.body}');
        return -1;
      }
    } catch (e) {
      debugPrint('Error saving marker: $e');
      return -1;
    }
  }

  Future<void> markDangerousPlace(NLatLng currentPosition) async {
    try {
      String markerName = 'marker_${DateTime.now().millisecondsSinceEpoch}';
      int result = await _saveMarkerToDB(username, currentPosition.latitude,
          currentPosition.longitude, 'bad', markerName);

      if (result == 1) {
        final marker = NMarker(
          id: markerName,
          position: currentPosition,
          icon: NOverlayImage.fromAssetImage('assets/images/dangerous_pin.png'),
          size: Size(50.0, 60.0),
          caption: NOverlayCaption(
            text: '위험한 곳',
            color: const Color(0xFFFF0000),
          ),
        );

        marker.setOnTapListener((NMarker clickedMarker) async {
          try {
            showDeleteConfirmationDialog(markerName, clickedMarker.info.id);
          } catch (e) {
            debugPrint('마커 클릭 처리 중 오류: $e');
          }
        });

        await mapController.addOverlay(marker);
        debugPrint('Dangerous place marker added successfully');
      } else {
        debugPrint('Failed to add dangerous place marker');
      }
    } catch (e) {
      debugPrint('Error adding dangerous place marker: $e');
    }
  }

  Future<void> markFavoritePlace(NLatLng currentPosition) async {
    try {
      String markerName = 'marker_${DateTime.now().millisecondsSinceEpoch}';
      int result = await _saveMarkerToDB(username, currentPosition.latitude,
          currentPosition.longitude, 'good', markerName);

      if (result == 1) {
        final marker = NMarker(
          id: markerName,
          position: currentPosition,
          icon: NOverlayImage.fromAssetImage('assets/images/good_pin.png'),
          size: Size(50.0, 60.0),
          caption: NOverlayCaption(
            text: '좋아하는 곳',
            color: const Color(0xFF00FF00),
          ),
        );

        marker.setOnTapListener((NMarker clickedMarker) async {
          try {
            showDeleteConfirmationDialog(markerName, clickedMarker.info.id);
          } catch (e) {
            debugPrint('마커 클릭 처리 중 오류: $e');
          }
        });

        await mapController.addOverlay(marker);
        debugPrint('Favorite place marker added successfully');
      } else {
        debugPrint('Failed to add favorite place marker');
      }
    } catch (e) {
      debugPrint('Error adding favorite place marker: $e');
    }
  }

  Future<String?> fetchMarkerName(double latitude, double longitude) async {
    final String baseUrl = dotenv.get('BASE_URL');
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/markers/getMarkerName'),
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
        return data['marker_name'];
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

          nMarker.setOnTapListener((NMarker clickedMarker) async {
            try {
              showDeleteConfirmationDialog(markerName, clickedMarker.info.id);

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

//드로어블 시트 위젯 모음
class DraggableSheetWidgets {
  static Widget dragHandle() {
    return Container(
      height: 3.0,
      width: 30.0,
      decoration: BoxDecoration(
        color: AppColors.workDSTGray,
        borderRadius: BorderRadius.circular(2.0),
      ),
    );
  }

  static Widget topSection({
    required double speed,
    required ValueListenable<int> timerController,
    required double totalDistance,
  }) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        Expanded(
          child: _textBox('시간', 's', speed, timerController, totalDistance),
        ),
        _verticalLine(),
        Expanded(
          child: _textBox('이동거리', 'm', speed, timerController, totalDistance),
        ),
        _verticalLine(),
        Expanded(
          child: _textBox('속력', 'km/h', speed, timerController, totalDistance),
        ),
      ],
    );
  }

  static Widget _textBox(String label, String type, double speed,
      ValueListenable<int> timerController, double totalDistance) {
    return Column(
      children: [
        Text(
          label,
          style: const TextStyle(
            color: Colors.black,
            fontSize: 14,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 7),
        ValueListenableBuilder<int>(
          valueListenable: timerController,
          builder: (context, time, child) {
            String displayValue = '';
            switch (type) {
              case 'km/h':
                displayValue = speed.toStringAsFixed(1);
                break;
              case 's':
                displayValue = FormatUtils.formatTime(time);
                break;
              case 'm':
                displayValue = totalDistance.toStringAsFixed(1) + ' m';
                break;
            }
            return Text(
              displayValue,
              style: const TextStyle(
                color: Colors.black,
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            );
          },
        ),
      ],
    );
  }

  // 세로 줄을 그리는 위젯
  static Widget _verticalLine() {
    return Container(
      width: 1,
      height: 90,
      color: AppColors.lightgreen,
    );
  }

  // 가로 줄을 그리는 위젯
  static Widget horizontalLine() {
    return Container(
      height: 2.0,
      width: 465.0,
      color: AppColors.lightgreen,
    );
  }

  //드로어블 시트의 하단 위젯
  static Widget bottomSection({
    required bool isRunning,
    required VoidCallback onStartPressed,
    required VoidCallback onStopPressed,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // 시작 버튼
          AnimatedOpacity(
            duration: const Duration(milliseconds: 200),
            opacity: isRunning ? 0.5 : 1.0,
            child: ElevatedButton(
              onPressed: isRunning ? null : onStartPressed,
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
                    color: isRunning ? Colors.grey[400] : Colors.white,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    '시작',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: isRunning ? Colors.grey[400] : Colors.white,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(width: 24),
          // 중지 버튼
          ElevatedButton(
            onPressed: isRunning ? onStopPressed : null,
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
                  color: isRunning ? Colors.white : Colors.grey[400],
                ),
                const SizedBox(width: 6),
                Text(
                  '중지',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: isRunning ? Colors.white : Colors.grey[400],
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
          if (distance >= 1) {
            totalDistance += distance;
            onDistanceUpdate(totalDistance);
            path.add(newLocation);

            NPathOverlay pathOverlay = NPathOverlay(
              id: "test",
              coords: path,
              color: AppColors.green,
              width: 5,
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
    final double roundedSpeed = double.parse(averageSpeed.toStringAsFixed(2));

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

      // 성공 응답 코드 범위 확장 (200, 201 모두 허용)
      if (response.statusCode >= 200 && response.statusCode < 300) {
        debugPrint('트랙 데이터 저장 성공');
        debugPrint('총 거리: $totalDistance m');
        debugPrint('평균 속도: $roundedSpeed km/h');
      } else {
        debugPrint('트랙 데이터 저장 실패: ${response.statusCode}');
        debugPrint('응답 내용: ${response.body}');
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
