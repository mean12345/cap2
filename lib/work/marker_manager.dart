import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_naver_map/flutter_naver_map.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_dotenv/flutter_dotenv.dart';

class MarkerManager {
  final NaverMapController mapController;
  final String username;
  final Function(String, String) showDeleteConfirmationDialog;

  MarkerManager({
    required this.mapController,
    required this.username,
    required this.showDeleteConfirmationDialog,
  });

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
            iconTintColor: markerType == 'bad' ? Colors.red : Colors.green,
            caption: NOverlayCaption(
              text: markerText,
              color: textColor,
            ),
          );

          nMarker.setOnTapListener((NMarker clickedMarker) async {
            try {
              showDeleteConfirmationDialog(markerName, clickedMarker.info.id);
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
