import 'package:dangq/colors.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:io';
import 'package:flutter_dotenv/flutter_dotenv.dart';

class EditProfilePage extends StatefulWidget {
  final String username;
  const EditProfilePage({super.key, required this.username});

  @override
  _EditProfilePageState createState() => _EditProfilePageState();
}

class _EditProfilePageState extends State<EditProfilePage> {
  final TextEditingController _nicknameController = TextEditingController();
  String? _profileImageUrl;
  File? _imageFile;

  @override
  void initState() {
    super.initState();
    _fetchProfileInfo();
  }

  @override
  void dispose() {
    _nicknameController.dispose();
    super.dispose();
  }

  Future<void> _fetchProfileInfo() async {
    final String baseUrl = dotenv.get('BASE_URL');
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/users/get_nickname?username=${widget.username}'),
      );

      if (response.statusCode == 200) {
        final jsonResponse = json.decode(response.body);
        setState(() {
          _nicknameController.text = jsonResponse['nickname'];
          _profileImageUrl = jsonResponse['profile_picture'];
        });
      } else {
        throw Exception('프로필 정보 불러오기 실패');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('프로필 정보 불러오기 실패!')),
        );
      }
    }
  }

  Future<void> _pickImage() async {
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 800, // 이미지 최대 너비 제한
      maxHeight: 800, // 이미지 최대 높이 제한
      imageQuality: 85, // 이미지 품질 (0-100)
    );

    if (pickedFile != null) {
      setState(() {
        _imageFile = File(pickedFile.path);
      });
    }
  }

  Future<void> _resetToDefaultProfile() async {
    final String baseUrl = dotenv.get('BASE_URL');

    try {
      final response = await http.post(
        Uri.parse('$baseUrl/users/reset_profile_picture'),
        headers: {
          'Content-Type': 'application/json'
        }, // Content-Type을 JSON으로 설정
        body: jsonEncode(
            {'username': widget.username}), // username을 JSON으로 인코딩하여 전달
      );

      if (response.statusCode == 200) {
        setState(() {
          _profileImageUrl = null; // 기본 프로필 이미지로 설정
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('기본 프로필 이미지로 되돌렸습니다!')),
        );
      } else {
        print("Error Response: ${response.body}");
        throw Exception('기본 프로필 이미지로 되돌리기 실패: ${response.body}');
      }
    } catch (e) {
      print("Error occurred while resetting profile: $e");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('기본 프로필 이미지로 되돌리기 실패!')),
        );
      }
    }
  }

  Future<void> _saveProfile() async {
    if (_nicknameController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('닉네임을 입력해주세요!')),
      );
      return;
    }

    final String baseUrl = dotenv.get('BASE_URL');
    var request = http.MultipartRequest(
      'POST',
      Uri.parse('$baseUrl/users/update_profile'),
    );

    // 기본 필드 추가
    request.fields['username'] = widget.username;
    request.fields['nickname'] = _nicknameController.text.trim();

    // 새 이미지가 선택된 경우에만 파일 추가
    if (_imageFile != null) {
      request.files.add(
        await http.MultipartFile.fromPath(
          'profile_picture',
          _imageFile!.path,
        ),
      );
    }

    try {
      final streamedResponse = await request.send();
      final response = await http.Response.fromStream(streamedResponse);

      if (response.statusCode == 200) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('프로필이 업데이트되었습니다!')),
          );
          Navigator.pop(context, true); // true를 반환하여 업데이트 성공을 알림
        }
      } else {
        throw Exception('프로필 업데이트 실패');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('프로필 업데이트 실패!')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      resizeToAvoidBottomInset: true,
      appBar: AppBar(
        scrolledUnderElevation: 0,
        toolbarHeight: MediaQuery.of(context).size.height * 0.07,
        title: const Text(
          '프로필 설정',
          style: TextStyle(
            color: Colors.black,
            fontSize: 17,
            fontWeight: FontWeight.w500,
          ),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
        backgroundColor: AppColors.background,
      ),
      body: Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(35),
              child: Column(
                children: [
                  SizedBox(
                    height: MediaQuery.of(context).size.height * 0.05,
                  ),
                  GestureDetector(
                    onTap: _pickImage,
                    child: CircleAvatar(
                      radius: 90,
                      backgroundColor: Colors.grey[200],
                      backgroundImage: _imageFile != null
                          ? FileImage(_imageFile!)
                          : (_profileImageUrl != null && _profileImageUrl!.isNotEmpty
                              ? NetworkImage(_profileImageUrl!) as ImageProvider
                              : null),
                      child: (_imageFile == null &&
                              (_profileImageUrl == null || _profileImageUrl!.isEmpty))
                          ? Icon(Icons.camera_alt,
                              size: 70, color: Colors.grey[600])
                          : null,
                    ),
                  ),
                  const SizedBox(height: 50),
                  SizedBox(
                    width: MediaQuery.of(context).size.width * 0.7,
                    child: TextField(
                      controller: _nicknameController,
                      decoration: InputDecoration(
                        hintText: '닉네임',
                        hintStyle: TextStyle(color: AppColors.workDSTGray),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(5),
                          borderSide: BorderSide(color: Colors.grey[400]!),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(5),
                          borderSide: BorderSide(
                              color: const Color.fromARGB(216, 158, 158, 158)),
                        ),
                        filled: true,
                        fillColor: Colors.grey[200],
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(5),
                          borderSide: BorderSide(color: AppColors.olivegreen),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          Container(
            padding: const EdgeInsets.all(35),
            child: Column(
              children: [
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: _saveProfile,
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      backgroundColor: AppColors.lightgreen,
                      foregroundColor: Colors.black,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(5),
                      ),
                    ),
                    child: const Text('저장'),
                  ),
                ),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: _resetToDefaultProfile,
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      backgroundColor: AppColors.lightgreen,
                      foregroundColor: Colors.black,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(5),
                      ),
                    ),
                    child: const Text('기본 프로필로 되돌리기'),
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
