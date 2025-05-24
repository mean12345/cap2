import 'package:flutter/material.dart';
import 'package:dangq/colors.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'dart:convert';
import 'dart:io';
import 'package:dangq/pages/main/main_page.dart';

class Fix_dog extends StatefulWidget {
  final String username;
  final int dogId;
  final String dogName;
  final String? imageUrl;

  const Fix_dog({
    super.key,
    required this.username,
    required this.dogId,
    required this.dogName,
    this.imageUrl,
  });

  @override
  State<Fix_dog> createState() => _Fix_dogState();
}

class _Fix_dogState extends State<Fix_dog> {
  late TextEditingController _nameController;
  final String baseUrl = dotenv.get('BASE_URL');

  Future<void> _deleteDogProfile() async {
    try {
      final url = '$baseUrl/dogs/${widget.dogId}';
      final response = await http.delete(Uri.parse(url));

      if (response.statusCode == 200) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('강아지 프로필이 삭제되었습니다.')),
          );
          Navigator.pop(context, true); // true를 반환하여 삭제되었음을 알림
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('삭제 실패: ${response.statusCode}')),
          );
        }
      }
    } catch (e) {
      print('강아지 프로필 삭제 오류: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('강아지 프로필 삭제 중 오류가 발생했습니다.')),
        );
      }
    }
  }

  void _showDeleteConfirmationDialog() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          backgroundColor: AppColors.background,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(5),
          ),
          title: Text('프로필 삭제'),
          content: Text('정말로 이 프로필을 삭제하시겠습니까?'),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text(
                '취소',
                style: TextStyle(color: Colors.grey[600]),
              ),
            ),
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
                _deleteDogProfile();
              },
              child: Text(
                '삭제',
                style: TextStyle(color: Colors.red),
              ),
            ),
          ],
        );
      },
    );
  }

  Future<void> _updateDogProfile() async {
    if (_nameController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('강아지 이름을 입력해주세요!')),
      );
      return;
    }

    try {
      final url = '$baseUrl/dogs/${widget.dogId}';
      print('요청 URL: $url');

      final response = await http.put(
        Uri.parse(url),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          'name': _nameController.text.trim(),
          'username': widget.username,
        }),
      );

      print('응답 상태 코드: ${response.statusCode}');
      print('응답 본문: ${response.body}');

      if (response.statusCode == 200) {
        if (mounted) {
          // 성공적으로 업데이트된 경우
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('강아지 프로필이 업데이트되었습니다!')),
          );

          // 이전 화면으로 돌아가면서 업데이트된 정보 전달
          Navigator.pop(context, {
            'dogId': widget.dogId,
            'updatedName': _nameController.text.trim(),
            'imageUrl': widget.imageUrl,
          });
        }
      } else {
        // 서버 오류 응답 처리
        String errorMessage = '프로필 업데이트에 실패했습니다';
        try {
          final decoded = json.decode(response.body);
          if (decoded is Map && decoded['message'] != null) {
            errorMessage = decoded['message'];
          }
        } catch (_) {
          // JSON 파싱 실패 시 콘솔에만 출력, 사용자에겐 일반 메시지
          print('서버 응답 파싱 오류: ${response.body}');
        }
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(errorMessage)),
          );
        }
      }
    } catch (e) {
      print('프로필 업데이트 오류: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('프로필 업데이트 중 오류가 발생했습니다.')),
        );
      }
    }
  }

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.dogName);
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      resizeToAvoidBottomInset: true,
      backgroundColor: AppColors.background,
      appBar: AppBar(
        toolbarHeight: MediaQuery.of(context).size.height * 0.05,
        leading: IconButton(
          icon: Icon(
            Icons.arrow_back,
            color: Colors.black,
            size: 35,
          ),
          onPressed: () {
            Navigator.pop(context);
          },
        ),
        actions: [
          IconButton(
            icon: Icon(
              Icons.delete_outline,
              color: Colors.black,
              size: 35,
            ),
            onPressed: _showDeleteConfirmationDialog,
          ),
        ],
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              child: Column(
                children: [
                  SizedBox(height: 80), // 120에서 80으로 줄임
                  //상단 프로필 사진
                  Container(
                    width: 160,
                    height: 160,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.grey[300],
                      image: widget.imageUrl != null
                          ? DecorationImage(
                              image: NetworkImage(widget.imageUrl!),
                              fit: BoxFit.cover,
                            )
                          : null,
                      border: Border.all(
                        color: const Color.fromARGB(255, 153, 153, 153),
                        width: 2,
                      ),
                    ),
                    child: widget.imageUrl == null
                        ? Icon(
                            Icons.pets,
                            size: 70,
                            color: const Color.fromARGB(255, 153, 153, 153),
                          )
                        : null,
                  ),
                  SizedBox(height: 30), // 동그라미와 텍스트 필드 사이 간격
                  //이름 텓스트 및 텍스트 상자
                  Container(
                    margin: EdgeInsets.symmetric(horizontal: 20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      //텍스트 상자 위의 이름
                      children: [
                        Text(
                          '이름',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        SizedBox(height: 8),
                        //텍스트 상자
                        Container(
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(5),
                          ),
                          child: TextField(
                            controller: _nameController,
                            autofocus: false,
                            decoration: InputDecoration(
                              hintText: '이름',
                              hintStyle: TextStyle(
                                color: Colors.grey[600],
                                fontSize: 16,
                              ),
                              contentPadding: EdgeInsets.symmetric(
                                  horizontal: 15, vertical: 15),
                              border: InputBorder.none,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  SizedBox(height: 200), // 키보드가 올라왔을 때 여백 확보
                ],
              ),
            ),
          ),
          //저장하기
          Container(
            width: double.infinity,
            height: 55,
            margin: EdgeInsets.fromLTRB(20, 0, 20, 30),
            child: ElevatedButton(
              onPressed: _updateDogProfile,
              child: Text(
                '저장하기',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.black,
                ),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.lightgreen,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(5),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
