import 'package:flutter/material.dart';
import 'package:flutter_naver_map/flutter_naver_map.dart';
import 'dart:math';
import '../colors.dart';

class WorkRoute extends StatelessWidget {
  final List<dynamic> pathData;
  final String username;
  final String createdAt;
  final String dogName;
  final String dogImageUrl;

  const WorkRoute({
    required this.pathData,
    required this.username,
    required this.createdAt,
    required this.dogName,
    required this.dogImageUrl,
    Key? key,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        scrolledUnderElevation: 0,
        toolbarHeight: MediaQuery.of(context).size.height * 0.07,
        title: const Text(
          '산책 기록',
          style: TextStyle(
            color: Colors.black,
            fontSize: 18,
            fontWeight: FontWeight.w500,
          ),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.of(context).pop(),
        ),
        backgroundColor: Colors.white,
        elevation: 0,
      ),
      body: Column(
        children: [
          // 정보 표시 섹션
          Container(
            padding: EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              boxShadow: [
                BoxShadow(
                  color: Colors.grey.withOpacity(0.2),
                  spreadRadius: 1,
                  blurRadius: 3,
                  offset: Offset(0, 2),
                ),
              ],
            ),
            child: Row(
              children: [
                // 강아지 프로필 이미지
                Container(
                  width: 50,
                  height: 50,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(color: AppColors.green, width: 2),
                  ),
                  child: CircleAvatar(
                    radius: 24,
                    backgroundImage: dogImageUrl.isNotEmpty
                        ? NetworkImage(dogImageUrl)
                        : AssetImage('assets/images/default_dog.png')
                            as ImageProvider,
                    backgroundColor: Colors.grey[300],
                  ),
                ),
                SizedBox(width: 12),
                // 정보 텍스트
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        dogName,
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      SizedBox(height: 4),
                      Text(
                        '$username • $createdAt',
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.grey[600],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          // 지도
          Expanded(
            child: NaverMap(
              options: const NaverMapViewOptions(
                locationButtonEnable: false,
                scaleBarEnable: false,
                initialCameraPosition: NCameraPosition(
                  target: NLatLng(35.853488, 128.488708),
                  zoom: 14,
                ),
              ),
              onMapReady: (controller) {
                if (pathData.isNotEmpty) {
                  print('=========== 경로 데이터 디버깅 시작 ===========');
                  print('경로 데이터 길이: ${pathData.length}');
                  print('첫 번째 좌표: ${pathData.first}');
                  print('마지막 좌표: ${pathData.last}');

                  try {
                    final List<NLatLng> coords = pathData
                        .map((point) {
                          print('좌표 변환 중: $point');
                          if (!point.containsKey('latitude') ||
                              !point.containsKey('longitude')) {
                            print('오류: 잘못된 좌표 형식 - $point');
                            return null;
                          }
                          try {
                            final lat =
                                double.parse(point['latitude'].toString());
                            final lng =
                                double.parse(point['longitude'].toString());
                            print('변환 성공 - lat: $lat, lng: $lng');
                            return NLatLng(lat, lng);
                          } catch (e) {
                            print('좌표 파싱 오류: $e');
                            return null;
                          }
                        })
                        .whereType<NLatLng>()
                        .toList();

                    print('변환된 좌표 개수: ${coords.length}');

                    if (coords.isEmpty) {
                      print('유효한 좌표가 없습니다');
                      return;
                    }

                    // 시작점과 끝점 마커 추가
                    if (coords.isNotEmpty) {
                      controller.addOverlay(NMarker(
                        id: 'start',
                        position: coords.first,
                        icon: NOverlayImage.fromAssetImage(
                            'assets/images/startingpoint_pin.png'),
                      ));

                      controller.addOverlay(NMarker(
                        id: 'end',
                        position: coords.last,
                        icon: NOverlayImage.fromAssetImage(
                            'assets/images/endingpoint_pin.png'),
                      ));
                    }

                    final pathOverlay = NPathOverlay(
                      id: 'path',
                      coords: coords,
                      color: Colors.green,
                      width: 5,
                    );

                    controller.addOverlay(pathOverlay);

                    // 경로가 모두 보이도록 카메라 조정
                    double minLat = coords.map((p) => p.latitude).reduce(min);
                    double maxLat = coords.map((p) => p.latitude).reduce(max);
                    double minLng = coords.map((p) => p.longitude).reduce(min);
                    double maxLng = coords.map((p) => p.longitude).reduce(max);

                    final bounds = NLatLngBounds(
                      southWest: NLatLng(minLat - 0.001, minLng - 0.001),
                      northEast: NLatLng(maxLat + 0.001, maxLng + 0.001),
                    );

                    controller.updateCamera(
                      NCameraUpdate.fitBounds(bounds,
                          padding: EdgeInsets.all(50)),
                    );
                  } catch (e) {
                    print('Error processing path data: $e');
                  }
                } else {
                  print('경로 데이터가 비어있습니다');
                }
              },
            ),
          ),
        ],
      ),
    );
  }
}
