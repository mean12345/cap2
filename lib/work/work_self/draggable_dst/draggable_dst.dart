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
import 'package:dangq/work/work_self/draggable_dst/timer_controller.dart';
import 'package:dangq/work/work_self/draggable_dst/format_utils.dart';
import 'package:dangq/work/check_place/selfplaceapp_popup.dart';
import 'package:dangq/work/work_self/draggable_dst/marker_manager.dart';
import 'package:dangq/work/work_self/draggable_dst/location_tracker.dart';
import 'package:dangq/work/work_self/draggable_dst/speed_tracker.dart';
import 'package:dangq/work/work_self/draggable_dst/draggable_sheet_widgets.dart';

//산책 페이지의 끌어 올리는 부분과 네이버 맵

class WorkDST extends StatefulWidget {
  final String username;
  final int dogId;
  const WorkDST({super.key, required this.username, required this.dogId});

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

  @override
  void initState() {
    super.initState();
    _speedTracker = SpeedTracker(
      onSpeedUpdate: (speed) => setState(() {}),
    );
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
                await _mapController.clearOverlays();
                await _markerManager?.loadMarkers();
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

  @override
  Widget build(BuildContext context) {
    final sheetPixelPosition =
        MediaQuery.of(context).size.height * _sheetPosition;

    return Stack(
      children: [
        //네이버 지도
        NaverMap(
          onMapReady: (controller) {
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
            _markerManager?.loadMarkers();
            controller.setLocationTrackingMode(NLocationTrackingMode.follow);
          },
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
      ],
    );
  }
}
