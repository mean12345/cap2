import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:dangq/colors.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:kpostal/kpostal.dart';

class AddPlaceDialog extends StatefulWidget {
  final String username;

  const AddPlaceDialog({super.key, required this.username});

  @override
  _AddPlaceDialogState createState() => _AddPlaceDialogState();
}

class _AddPlaceDialogState extends State<AddPlaceDialog> {
  bool isDangerous = false;
  bool isFavorite = false;
  String postCode = '';
  String address = '';
  double? latitude;
  double? longitude;

  void _saveMarker() async {
    // markerName 생성
    String markerName = 'marker_${DateTime.now().millisecondsSinceEpoch}';
    String markerType = isDangerous
        ? 'bad'
        : isFavorite
            ? 'good'
            : 'neutral';

    debugPrint('Saving marker: $markerName, Type: $markerType');

    // latitude와 longitude가 null인 경우 예외 처리
    if (latitude == null || longitude == null) {
      debugPrint('Error: Latitude or Longitude is null');
      // ScaffoldMessenger.showSnackBar로 SnackBar 표시
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('위치 정보가 올바르지 않습니다.')),
      );
      return; // 위치 정보가 없으면 함수를 종료
    }

    // DB에 마커 저장
    int result = await _saveMarkerToDB(
      widget.username,
      latitude!,
      longitude!,
      markerType,
      markerName,
    );

    // 결과 로그 및 SnackBar 표시
    debugPrint('Save result: $result');

    if (result == 1) {
      // 팝업 닫기
      Navigator.of(context).pop();
    }

    // SnackBar 표시
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(result == 1
            ? 'Marker saved successfully!'
            : 'Failed to save marker'),
      ),
    );
  }

  Future<int> _saveMarkerToDB(String userName, double latitude,
      double longitude, String markerType, String markerName) async {
    final String baseUrl = dotenv.get('BASE_URL');
    debugPrint('Base URL: $baseUrl');
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

      debugPrint('Response status: ${response.statusCode}');
      return response.statusCode == 201 ? 1 : -1;
    } catch (e) {
      debugPrint('Error saving marker: $e');
      return -1;
    }
  }

  void _onDangerousAreaChanged(bool? value) {
    debugPrint('Dangerous area changed: $value');
    setState(() {
      isFavorite = false;
      isDangerous = value ?? false;
    });
  }

  void _onFavoriteAreaChanged(bool? value) {
    debugPrint('Favorite area changed: $value');
    setState(() {
      isDangerous = false;
      isFavorite = value ?? false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: () async => false,
      child: Dialog(
        backgroundColor: AppColors.background,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(5),
          side: BorderSide(
            color: AppColors.lightgreen,
            width: 2.0,
          ),
        ),
        insetPadding: EdgeInsets.symmetric(horizontal: 20, vertical: 20),
        child: SizedBox(
          width: 340,
          child: Stack(
            children: [
              buildCloseButton(context),
              Padding(
                padding: const EdgeInsets.all(20.0),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    SizedBox(height: 10),
                    buildCategoryTitle(),
                    buildCheckboxRow(),
                    SizedBox(height: 16),
                    buildAddressTitle(),
                    SizedBox(height: 8),
                    buildAddressInput(context),
                    SizedBox(height: 15),
                    buildLatitudeLongitude(),
                    SizedBox(height: 20),
                    buildSaveButton(),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget buildCloseButton(BuildContext context) {
    return Positioned(
      top: 0.5,
      right: 0.5,
      child: Padding(
        padding: const EdgeInsets.all(3),
        child: IconButton(
          icon: Icon(Icons.close),
          iconSize: 30,
          onPressed: () {
            Navigator.of(context).pop();
          },
        ),
      ),
    );
  }

  Widget buildCategoryTitle() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 5.0),
          child: Text(
            '종류 선택',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
        ),
      ],
    );
  }

  Widget buildCheckboxRow() {
    return Padding(
      padding: const EdgeInsets.only(left: 20.0),
      child: Column(
        children: [
          Row(
            children: [
              Text('위험한 지역', style: TextStyle(fontSize: 16)),
              Checkbox(
                value: isDangerous,
                onChanged: _onDangerousAreaChanged,
                checkColor: Colors.white,
                activeColor: AppColors.lightgreen,
                side: BorderSide(
                  color: AppColors.lightgreen,
                  width: 2.0,
                ),
              ),
              SizedBox(width: 10),
              Text('좋아한 지역', style: TextStyle(fontSize: 16)),
              Checkbox(
                value: isFavorite,
                onChanged: _onFavoriteAreaChanged,
                checkColor: Colors.white,
                activeColor: AppColors.lightgreen,
                side: BorderSide(
                  color: AppColors.lightgreen,
                  width: 2.0,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget buildAddressTitle() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 5.0),
          child: Text(
            '주소',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
        ),
      ],
    );
  }

  Widget buildAddressInput(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20.0),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                flex: 2,
                child: Container(
                  height: 40,
                  decoration: BoxDecoration(
                    border: Border.all(color: AppColors.workDSTGray),
                    borderRadius: BorderRadius.circular(5),
                  ),
                  child: TextField(
                    readOnly: true,
                    controller: TextEditingController(text: postCode),
                    decoration: InputDecoration(
                      border: InputBorder.none,
                      contentPadding:
                          EdgeInsets.symmetric(horizontal: 8, vertical: 10),
                      hintText: '우편번호',
                    ),
                  ),
                ),
              ),
              SizedBox(width: 8),
              Expanded(
                flex: 1,
                child: ElevatedButton(
                  onPressed: () async {
                    await Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => KpostalView(
                          useLocalServer: true,
                          localPort: 1024,
                          callback: (Kpostal result) {
                            setState(() {
                              postCode = result.postCode ?? '';
                              address = result.address ?? '';
                              latitude = result.latitude ?? 0.0;
                              longitude = result.longitude ?? 0.0;
                            });
                          },
                        ),
                      ),
                    );
                  },
                  style: ElevatedButton.styleFrom(
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(5),
                      side: BorderSide(
                        color: AppColors.workDSTGray,
                        width: 1.0,
                      ),
                    ),
                    minimumSize: Size(0, 40),
                    backgroundColor: AppColors.background,
                    padding: EdgeInsets.symmetric(horizontal: 2),
                  ),
                  child: Text(
                    '주소찾기',
                    style: TextStyle(color: Colors.black),
                  ),
                ),
              ),
            ],
          ),
          SizedBox(height: 8),
          Container(
            height: 40,
            decoration: BoxDecoration(
              border: Border.all(color: AppColors.workDSTGray),
              borderRadius: BorderRadius.circular(5),
            ),
            child: TextField(
              readOnly: true,
              controller: TextEditingController(text: address),
              decoration: InputDecoration(
                border: InputBorder.none,
                contentPadding:
                    EdgeInsets.symmetric(horizontal: 8, vertical: 10),
                hintText: '주소',
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget buildLatitudeLongitude() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '위도: ${latitude ?? '불명'}',
          style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
        ),
        Text(
          '경도: ${longitude ?? '불명'}',
          style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
        ),
      ],
    );
  }

  Widget buildSaveButton() {
    return ElevatedButton(
      style: ElevatedButton.styleFrom(
        minimumSize: Size(double.infinity, 40),
        backgroundColor: AppColors.lightgreen,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(5),
        ),
      ),
      onPressed: () {
        if (isDangerous || isFavorite) {
          _saveMarker();
        } else {
          print('지역을 선택해 주세요');
        }
      },
      child: Text(
        '저장하기',
        style: TextStyle(
          color: Colors.black,
          fontSize: 16,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }
}
