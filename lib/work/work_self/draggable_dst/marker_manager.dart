import 'package:flutter/material.dart';
import 'package:flutter_naver_map/flutter_naver_map.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'dart:convert';
import 'package:dangq/colors.dart';

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

      await mapController.clearOverlays();
      List<Map<String, dynamic>> markers = await fetchMarkersFromDB();
      debugPrint('DB에서 마커 불러오기 완료: ${markers.length}개 마커');

      for (var marker in markers) {
        NLatLng position = NLatLng(
          double.parse(marker['latitude'].toString()),
          double.parse(marker['longitude'].toString()),
        );

        String markerType = marker['markerType'].toString();
        String markerName = marker['markerName'].toString();

        String marker_Type = marker['markerType'].toString();
        String marker_Name = 'marker_${DateTime.now().millisecondsSinceEpoch}';

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

        await mapController.addOverlay(nMarker);
        debugPrint('마커 추가 완료: $markerName (타입: $markerType)');
      }

      debugPrint('총 ${markers.length}개의 마커 로드 완료');
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
