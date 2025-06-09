// lib/work/walk_choose.dart

import 'dart:async';
import 'dart:convert';
import 'dart:developer';
import 'dart:math';
import 'package:dangq/colors.dart';
import 'package:dangq/work/work_self/work.dart';
import 'package:dangq/work/dog_list.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_naver_map/flutter_naver_map.dart';
import 'package:http/http.dart' as http;
import 'package:dangq/work/navigation/route_select_page.dart'; // route.dart import
import 'package:geolocator/geolocator.dart'; // 상단에 추가

class WalkChoose extends StatefulWidget {
  final String username;
  final int dogId;
  final String dogName;

  const WalkChoose({
    super.key,
    required this.username,
    required this.dogId,
    required this.dogName,
  });

  @override
  State<WalkChoose> createState() => WalkChooseState();
}

class WalkChooseState extends State<WalkChoose> {
  List<Map<String, dynamic>> dogProfiles = [];
  bool _isLoading = false;

  late int _selectedDogId;
  late String _selectedDogName;
  String _selectedDogImageUrl = '';
  final String baseUrl =
      dotenv.env['BASE_URL']!; // ex: "http://114.71.1.183:3000"

  // ─────────────────────────────────────────────────────────
  // 1) NaverMapController와 최종 경로 좌표를 저장할 변수
  // ─────────────────────────────────────────────────────────
  NaverMapController? _mapController;
  List<NLatLng> _routeCoords = [];

  // 현재 위치 관련 변수 추가
  NLatLng? _currentLocation;
  bool _locationLoading = true;

  bool _isTracking = false;
  Timer? _locationTimer;

  // 마커 관련 변수 추가
  MarkerManager? _markerManager;
  bool _showMarkers = true;

  @override
  void initState() {
    super.initState();
    _selectedDogId = widget.dogId;
    _selectedDogName = widget.dogName;
    _fetchDogProfiles();
    _getCurrentLocation(); // 현재 위치 가져오기
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // 페이지가 다시 포커스를 받을 때 마커 다시 로드
    if (_mapController != null && _markerManager != null) {
      _markerManager?.loadMarkers();
    }
  }

  void _startLocationTracking() {
    _locationTimer?.cancel();
    _locationTimer =
        Timer.periodic(const Duration(milliseconds: 1500), (timer) async {
      // 1.5초 간격으로 변경
      try {
        Position position = await Geolocator.getCurrentPosition(
          desiredAccuracy: LocationAccuracy.medium, // 정확도를 medium으로 설정
          timeLimit: const Duration(seconds: 2), // 타임아웃 2초로 설정
        );
        if (mounted) {
          setState(() {
            _currentLocation = NLatLng(position.latitude, position.longitude);
          });
          if (_mapController != null) {
            await _mapController!.updateCamera(
              NCameraUpdate.withParams(
                target: _currentLocation!,
                zoom: 15,
              ),
            );
          }
        }
      } catch (e) {
        debugPrint('위치 업데이트 오류: $e');
      }
    });
    setState(() {
      _isTracking = true;
    });
  }

  @override
  void dispose() {
    _locationTimer?.cancel(); // 페이지 종료 시 타이머 취소
    super.dispose();
  }

  void _updateSelectedDog(int dogId, String dogName, String imageUrl) {
    setState(() {
      _selectedDogId = dogId;
      _selectedDogName = dogName;
      _selectedDogImageUrl = imageUrl;
    });
  }

  Future<void> _fetchDogProfiles() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final url = '$baseUrl/dogs/get_dogs?username=${widget.username}';
      final response = await http.get(Uri.parse(url));

      if (response.statusCode == 404) {
        setState(() {
          dogProfiles = [];
          _isLoading = false;
        });
        return;
      }
      if (response.statusCode == 200) {
        final List<dynamic> jsonResponse = json.decode(response.body);
        setState(() {
          dogProfiles = jsonResponse
              .map((dog) => {
                    'dog_name': dog['name'],
                    'image_url': dog['imageUrl'],
                    'id': dog['id'],
                  })
              .toList();

          final selectedDog = dogProfiles.firstWhere(
            (dog) => dog['id'] == _selectedDogId,
            orElse: () => dogProfiles.isNotEmpty
                ? dogProfiles[0]
                : {
                    'dog_name': _selectedDogName,
                    'image_url': '',
                    'id': _selectedDogId,
                  },
          );

          _selectedDogId = selectedDog['id'];
          _selectedDogName = selectedDog['dog_name'];
          _selectedDogImageUrl = selectedDog['image_url'] ?? '';
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

  // 현재 위치 가져오는 함수
  Future<void> _getCurrentLocation() async {
    try {
      // 먼저 마지막으로 알려진 위치를 가져옴 (즉시 응답)
      Position? lastKnownPosition = await Geolocator.getLastKnownPosition();
      if (lastKnownPosition != null) {
        setState(() {
          _currentLocation =
              NLatLng(lastKnownPosition.latitude, lastKnownPosition.longitude);
          _locationLoading = false;
        });
      }

      // 권한 체크와 실제 위치 가져오기를 병렬로 처리
      await Future.wait([
        Geolocator.requestPermission(),
        Geolocator.getCurrentPosition(
          desiredAccuracy: LocationAccuracy.medium, // 정확도를 medium으로 낮춤
          timeLimit: const Duration(seconds: 3), // 타임아웃 설정
        ).then((position) {
          setState(() {
            _currentLocation = NLatLng(position.latitude, position.longitude);
            _locationLoading = false;
          });
        }).catchError((e) {
          debugPrint('정확한 위치 가져오기 실패: $e');
        }),
      ]);
    } catch (e) {
      setState(() => _locationLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        toolbarHeight: MediaQuery.of(context).size.height * 0.05,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () {
            // 선택된 강아지 정보를 메인 페이지로 전달
            Navigator.pop(context, {
              'selectedDogId': _selectedDogId, // 'dogId'에서 'selectedDogId'로 변경
              'dogName': _selectedDogName,
              'imageUrl': _selectedDogImageUrl,
            });
          },
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        systemOverlayStyle: SystemUiOverlayStyle.dark,
      ),
      body: Stack(
        children: [
          NaverMap(
            onMapReady: (controller) async {
              _mapController = controller;
              controller.setLocationTrackingMode(NLocationTrackingMode.follow);
              _startLocationTracking();

              // 마커 매니저 초기화
              _markerManager = MarkerManager(
                mapController: controller,
                username: widget.username,
                showDeleteConfirmationDialog: (_, __) {}, // 빈 함수로 대체
              );

              // 마커 로드
              await _markerManager?.loadMarkers();

              if (_currentLocation != null) {
                await controller.updateCamera(
                  NCameraUpdate.withParams(
                    target: _currentLocation!,
                    zoom: 15,
                  ),
                );
              }
            },
            options: NaverMapViewOptions(
              locationButtonEnable: true,
              indoorEnable: true,
              consumeSymbolTapEvents: false,
              initialCameraPosition: NCameraPosition(
                target:
                    _currentLocation ?? const NLatLng(37.5666102, 126.9783881),
                zoom: 15,
              ),
            ),
          ),

          // ────────────────────────────────────────────────────
          // (2) 하단 패널: "경로 추천 받기" / "산책하기" 버튼 및 프로필
          // ────────────────────────────────────────────────────
          Positioned(
            bottom: 0,
            child: Container(
              width: MediaQuery.of(context).size.width,
              height: MediaQuery.of(context).size.height * 0.25,
              decoration: const BoxDecoration(color: Colors.white),
              child: Padding(
                padding: const EdgeInsets.only(top: 35),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    // ────────────────────────────────────────────
                    // (2-1) "경로 추천 받기" 버튼
                    // ────────────────────────────────────────────
                    GestureDetector(
                      onTap: () async {
                        // ① 출발/도착/경유지 화면을 거쳐 allPoints 받아오기
                        final routeResult = await Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => RouteWithStopoverPage(
                              username: widget.username,
                              dogId: _selectedDogId,
                              dogName: _selectedDogName,
                            ),
                          ),
                        );

                        // routeResult가 null이면 함수 종료
                        if (routeResult == null) {
                          return;
                        }

                        // 프로필 정보 업데이트
                        if (routeResult is Map<String, dynamic> &&
                            routeResult.containsKey('dogId') &&
                            routeResult.containsKey('dogName') &&
                            routeResult.containsKey('imageUrl')) {
                          _updateSelectedDog(
                            routeResult['dogId'],
                            routeResult['dogName'],
                            routeResult['imageUrl'],
                          );
                        }

                        // 경로가 생성된 경우에만 Work 화면으로 이동
                        if (routeResult is Map<String, dynamic> &&
                            routeResult.containsKey('forwardPath') &&
                            routeResult.containsKey('reversePath')) {
                          await Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => Work(
                                username: widget.username,
                                dogId: _selectedDogId,
                                dogName: _selectedDogName,
                                forwardPath: routeResult['forwardPath'],
                                reversePath: routeResult['reversePath'],
                              ),
                            ),
                          ).then((_) {
                            // Work 페이지에서 돌아올 때 마커 다시 로드
                            if (_mapController != null &&
                                _markerManager != null) {
                              _mapController!.clearOverlays().then((_) {
                                _markerManager?.loadMarkers();
                              });
                            }
                          });
                        }
                      },
                      child: Container(
                        width: 300,
                        height: 45,
                        margin: const EdgeInsets.only(bottom: 15),
                        decoration: BoxDecoration(
                          color: AppColors.lightgreen,
                          borderRadius: BorderRadius.circular(5),
                        ),
                        child: const Center(
                          child: Text(
                            '경로 추천 받기',
                            style: TextStyle(
                              color: Colors.black,
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                    ),

                    // ────────────────────────────────────────────
                    // (2-2) "산책하기" 버튼: 기존 Work 화면으로 이동
                    // ────────────────────────────────────────────
                    GestureDetector(
                      onTap: () async {
                        await Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => Work(
                              username: widget.username,
                              dogId: _selectedDogId,
                              dogName: _selectedDogName,
                            ),
                          ),
                        ).then((result) {
                          if (result != null &&
                              result is Map<String, dynamic>) {
                            _updateSelectedDog(
                              result['dogId'],
                              result['dogName'],
                              result['imageUrl'],
                            );
                          }

                          // Work 페이지에서 돌아올 때 마커 다시 로드
                          if (_mapController != null &&
                              _markerManager != null) {
                            _mapController!.clearOverlays().then((_) {
                              _markerManager?.loadMarkers();
                            });
                          }
                        });
                      },
                      child: Container(
                        width: 300,
                        height: 45,
                        margin: const EdgeInsets.only(bottom: 15),
                        decoration: BoxDecoration(
                          color: AppColors.lightgreen,
                          borderRadius: BorderRadius.circular(5),
                        ),
                        child: const Center(
                          child: Text(
                            '산책하기',
                            style: TextStyle(
                              color: Colors.black,
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),

          // ─────────────────────────────────────────────────────────
          // (3) 강아지 프로필 원형 (왼쪽)
          // ─────────────────────────────────────────────────────────
          Positioned(
            bottom: MediaQuery.of(context).size.height * 0.19,
            left: 15,
            child: GestureDetector(
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => DogListPage(
                      username: widget.username,
                      onDogSelected: (int id, String name, String imageUrl) {
                        _updateSelectedDog(id, name, imageUrl);
                      },
                    ),
                  ),
                );
              },
              child: Container(
                width: 100,
                height: 100,
                decoration: const BoxDecoration(
                  color: Colors.white,
                  shape: BoxShape.circle,
                ),
                child: Center(
                  child: _isLoading
                      ? const CircularProgressIndicator()
                      : _selectedDogImageUrl.isEmpty
                          ? const Icon(Icons.pets, size: 50, color: Colors.grey)
                          : ClipOval(
                              child: Image.network(
                                _selectedDogImageUrl,
                                width: 85,
                                height: 85,
                                fit: BoxFit.cover,
                                errorBuilder: (context, error, stackTrace) {
                                  return const Icon(Icons.pets,
                                      size: 50, color: Colors.grey);
                                },
                              ),
                            ),
                ),
              ),
            ),
          ),

          // ─────────────────────────────────────────────────────────
          // (4) 강아지 이름 텍스트
          // ─────────────────────────────────────────────────────────
          Positioned(
            bottom: MediaQuery.of(context).size.height * 0.21,
            left: 125,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _selectedDogName,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// ─────────────────────────────────────────────────────────
  /// 지도에 폴리라인+마커 그리기
  /// ─────────────────────────────────────────────────────────
  Future<void> _drawRoute(List<NLatLng> coords) async {
    if (_mapController == null || coords.isEmpty) return;

    // (1) 모든 오버레이(마커+폴리라인) 제거
    await _mapController!.clearOverlays();

    // (2) 초록색 폴리라인 추가
    final polyline = NPolylineOverlay(
      id: 'recommended_route',
      coords: coords,
      width: 5,
      color: AppColors.green,
    );
    await _mapController!.addOverlay(polyline);

    // (3) 출발지/도착지/경유지 마커 찍기
    if (coords.isNotEmpty) {
      // 출발지 마커 (초록색)
      final startMarker = NMarker(
        id: 'start_marker',
        position: coords.first,
        iconTintColor: Colors.green,
      );
      await _mapController!.addOverlay(startMarker);
    }
    if (coords.length >= 2) {
      // 도착지 마커 (초록색)
      final endMarker = NMarker(
        id: 'end_marker',
        position: coords.last,
        iconTintColor: Colors.green,
      );
      await _mapController!.addOverlay(endMarker);
    }
    // 경유지 마커 (노란색): 첫/마지막 제외
    for (int i = 1; i < coords.length - 1; i++) {
      final stopoverMarker = NMarker(
        id: 'mid_$i',
        position: coords[i],
        iconTintColor: Colors.yellow,
      );
      await _mapController!.addOverlay(stopoverMarker);
    }

    setState(() {
      _routeCoords = coords;
    });
  }
}

// 마커 관리 클래스
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
