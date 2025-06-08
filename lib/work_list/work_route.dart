import 'package:flutter/material.dart';
import 'package:flutter_naver_map/flutter_naver_map.dart';
import 'dart:math';

class WorkRoute extends StatelessWidget {
  final List<dynamic> pathData;

  const WorkRoute({
    required this.pathData,
    Key? key,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('산책 경로'),
        backgroundColor: Colors.green,
        leading: IconButton(
          icon: Icon(Icons.arrow_back),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: NaverMap(
        options: NaverMapViewOptions(
          initialCameraPosition: NCameraPosition(
            target: NLatLng(37.5666102, 126.9783881),
            zoom: 15,
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
                      final lat = double.parse(point['latitude'].toString());
                      final lng = double.parse(point['longitude'].toString());
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
                  caption: NOverlayCaption(text: '시작', color: Colors.blue),
                ));

                controller.addOverlay(NMarker(
                  id: 'end',
                  position: coords.last,
                  caption: NOverlayCaption(text: '종료', color: Colors.red),
                ));
              }

              final pathOverlay = NPathOverlay(
                id: 'path',
                coords: coords,
                color: Colors.blue,
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
                NCameraUpdate.fitBounds(bounds, padding: EdgeInsets.all(50)),
              );
            } catch (e) {
              print('Error processing path data: $e');
            }
          } else {
            print('경로 데이터가 비어있습니다');
          }
        },
      ),
    );
  }
}