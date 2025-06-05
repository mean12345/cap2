// lib/work/walk_choose.dart

import 'dart:convert';
import 'package:dangq/colors.dart';
import 'package:dangq/work/work_self/work.dart';
import 'package:dangq/work/dog_list.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_naver_map/flutter_naver_map.dart';
import 'package:http/http.dart' as http;
import 'package:dangq/pages/navigation/route_select_page.dart'; // route.dart import

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

  @override
  void initState() {
    super.initState();
    _selectedDogId = widget.dogId;
    _selectedDogName = widget.dogName;
    _fetchDogProfiles();
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        toolbarHeight: MediaQuery.of(context).size.height * 0.05,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black, size: 35),
          onPressed: () {
            Navigator.pop(context, {
              'dogId': _selectedDogId,
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
          // ────────────────────────────────────────────────────
          // (1) NaverMap 위젯: 컨트롤러 취득
          // ────────────────────────────────────────────────────
          NaverMap(
            onMapReady: (controller) {
              _mapController = controller;
            },
            options: const NaverMapViewOptions(
              locationButtonEnable: false,
              initialCameraPosition: NCameraPosition(
                target: NLatLng(37.5666102, 126.9783881),
                zoom: 15,
              ),
            ),
          ),

          // ────────────────────────────────────────────────────
          // (2) 하단 패널: “경로 추천 받기” / “산책하기” 버튼 및 프로필
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
                    // (2-1) “경로 추천 받기” 버튼
                    // ────────────────────────────────────────────
                    GestureDetector(
                      onTap: () async {
                        // ① 출발/도착/경유지 화면을 거쳐 allPoints 받아오기
                        final routeResult = await Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => RouteWithStopoverPage(
                              username: widget.username,
                              dogId: widget.dogId,
                            ),
                          ),
                        );

                        // routeResult가 null이면 함수 종료
                        if (routeResult == null) {
                          return;
                        }

                        // 경로가 생성된 경우에만 Work 화면으로 이동
                        if (routeResult is Map<String, dynamic> &&
                            routeResult.containsKey('forwardPath') &&
                            routeResult.containsKey('reversePath')) {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => Work(
                                username: widget.username,
                                dogId: _selectedDogId,
                                dogName: _selectedDogName,
                                // 필요 시: pathCoords: coords
                              ),
                            ),
                          );
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
                    // (2-2) “산책하기” 버튼: 기존 Work 화면으로 이동
                    // ────────────────────────────────────────────
                    GestureDetector(
                      onTap: () {
                        Navigator.push(
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

    // (2) 파란색 폴리라인 추가
    final polyline = NPolylineOverlay(
      id: 'recommended_route',
      coords: coords,
      width: 5,
      color: Colors.blue,
    );
    await _mapController!.addOverlay(polyline);

    // (3) 출발지/도착지/경유지 마커 찍기
    if (coords.isNotEmpty) {
      // 출발지 마커 (파란색)
      final startMarker = NMarker(
        id: 'start_marker',
        position: coords.first,
        iconTintColor: Colors.blue,
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
