import 'package:dangq/colors.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:io';
import 'package:flutter_dotenv/flutter_dotenv.dart';

class EditDogProfilePage extends StatefulWidget {
  final String username;
  const EditDogProfilePage({super.key, required this.username});

  @override
  _EditDogProfilePageState createState() => _EditDogProfilePageState();
}

class _EditDogProfilePageState extends State<EditDogProfilePage> {
  final TextEditingController _nameController = TextEditingController();
  String? _dogImageUrl;
  File? _imageFile;

  @override
  void initState() {
    super.initState();
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 800,
      maxHeight: 800,
      imageQuality: 85,
    );

    if (pickedFile != null) {
      setState(() {
        _imageFile = File(pickedFile.path);
      });
    }
  }

  Future<void> _resetToDefaultDogProfile() async {
    final String baseUrl = dotenv.get('BASE_URL');

    try {
      final response = await http.post(
        Uri.parse('$baseUrl/dogs/reset_profile_picture'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'dogId': widget.username}),
      );

      if (response.statusCode == 200) {
        setState(() {
          _dogImageUrl = null;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('기본 강아지 이미지로 되돌렸습니다!')),
        );
      } else {
        throw Exception('기본 이미지로 되돌리기 실패: ${response.body}');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('기본 이미지로 되돌리기 실패!')),
        );
      }
    }
  }

  Future<void> _saveDogProfile() async {
    if (_nameController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('강아지 이름을 입력해주세요!')),
      );
      return;
    }

    final String baseUrl = dotenv.get('BASE_URL'); // .env에서 BASE_URL 가져옴
    String? imageUrl;

    try {
      if (_imageFile != null) {
        // 이미지 파일 업로드
        var imageRequest = http.MultipartRequest(
          'POST',
          Uri.parse('$baseUrl/dogs/dogs_profile'),
        );
        imageRequest.files.add(
          await http.MultipartFile.fromPath('image', _imageFile!.path),
        );

        final imageResponse = await imageRequest.send();
        final imageBody = await http.Response.fromStream(imageResponse);
        print('이미지 업로드 응답 코드: ${imageBody.statusCode}');
        print('응답 본문: ${imageBody.body}');
        if (imageBody.statusCode == 200) {
          final imageJson = jsonDecode(imageBody.body);
          imageUrl = imageJson['url'];
        } else {
          throw Exception('이미지 업로드 실패');
        }
      }

      // 강아지 정보 등록
      final profileResponse = await http.post(
        Uri.parse('$baseUrl/dogs'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'username': widget.username,
          'dog_name': _nameController.text.trim(),
          'image_url': imageUrl,
        }),
      );

      if (profileResponse.statusCode == 201) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('강아지 프로필이 등록되었습니다!')),
          );
          Navigator.pop(context, true);
        }
      } else {
        throw Exception('강아지 프로필 등록 실패');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('강아지 프로필 등록 중 오류가 발생했습니다.')),
        );
      }
      print('오류 발생: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('강아지 프로필 수정'),
        backgroundColor: AppColors.background,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(35),
        child: Column(
          children: [
            SizedBox(height: MediaQuery.of(context).size.height * 0.05),
            GestureDetector(
              onTap: _pickImage,
              child: CircleAvatar(
                radius: 90,
                backgroundColor: Colors.grey[200],
                backgroundImage: _imageFile != null
                    ? FileImage(_imageFile!)
                    : (_dogImageUrl != null && _dogImageUrl!.isNotEmpty
                        ? NetworkImage(_dogImageUrl!) as ImageProvider
                        : null),
                child: (_imageFile == null &&
                        (_dogImageUrl == null || _dogImageUrl!.isEmpty))
                    ? Icon(Icons.pets, size: 70, color: Colors.grey[600])
                    : null,
              ),
            ),
            const SizedBox(height: 50),
            SizedBox(
              width: MediaQuery.of(context).size.width * 0.7,
              child: TextField(
                controller: _nameController,
                decoration: InputDecoration(
                  hintText: '강아지 이름',
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
            const SizedBox(height: 50),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _saveDogProfile,
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  backgroundColor: AppColors.olivegreen,
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
                onPressed: _resetToDefaultDogProfile,
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  backgroundColor: AppColors.olivegreen,
                  foregroundColor: Colors.black,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(5),
                  ),
                ),
                child: const Text('기본 강아지 이미지로 되돌리기'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
