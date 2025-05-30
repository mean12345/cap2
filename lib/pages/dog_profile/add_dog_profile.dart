import 'package:dangq/colors.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:io';
import 'package:flutter_dotenv/flutter_dotenv.dart';

class EditDogProfilePage extends StatefulWidget {
  final String username;
  final Map<String, dynamic>? dogProfile; // 기존 강아지 정보를 받기 위한 파라미터 추가

  const EditDogProfilePage({
    super.key,
    required this.username,
    this.dogProfile, // 업데이트할 때는 기존 정보가 들어옴
  });

  @override
  _EditDogProfilePageState createState() => _EditDogProfilePageState();
}

class _EditDogProfilePageState extends State<EditDogProfilePage> {
  final TextEditingController _nameController = TextEditingController();
  String? _dogImageUrl;
  File? _imageFile;
  bool _isUpdating = false; // 업데이트 모드인지 확인하는 플래그

  @override
  void initState() {
    super.initState();

    // 기존 강아지 정보가 있으면 폼에 채워넣기
    if (widget.dogProfile != null) {
      _isUpdating = true;
      _nameController.text = widget.dogProfile!['name'] ?? '';
      _dogImageUrl = widget.dogProfile!['imageUrl'];
    }
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
        body: jsonEncode({'dogId': widget.dogProfile!['id']}), // dogId 사용
      );

      if (response.statusCode == 200) {
        setState(() {
          _dogImageUrl = null;
          _imageFile = null;
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

  Future<void> _updateDogProfile() async {
    if (_nameController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('강아지 이름을 입력해주세요!')),
      );
      return;
    }

    final String baseUrl = dotenv.get('BASE_URL');
    String? imageUrl = _dogImageUrl; // 기존 이미지 URL 유지

    try {
      // 새로운 이미지가 선택되었다면 업로드
      if (_imageFile != null) {
        var imageRequest = http.MultipartRequest(
          'POST',
          Uri.parse('$baseUrl/dogs/dogs_profile'),
        );
        imageRequest.files.add(
          await http.MultipartFile.fromPath('image', _imageFile!.path),
        );

        final imageResponse = await imageRequest.send();
        final imageBody = await http.Response.fromStream(imageResponse);

        if (imageBody.statusCode == 200) {
          final imageJson = jsonDecode(imageBody.body);
          imageUrl = imageJson['url'];
        } else {
          throw Exception('이미지 업로드 실패');
        }
      }

      // 강아지 프로필 업데이트
      final profileResponse = await http.put(
        Uri.parse('$baseUrl/dogs/update/${widget.dogProfile!['id']}'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'dog_name': _nameController.text.trim(),
          'image_url': imageUrl,
        }),
      );

      if (profileResponse.statusCode == 200) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('강아지 프로필이 수정되었습니다!')),
          );
          Navigator.pop(context, true);
        }
      } else {
        throw Exception('강아지 프로필 수정 실패');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('강아지 프로필 수정 중 오류가 발생했습니다.')),
        );
      }
      print('오류 발생: $e');
    }
  }

  Future<void> _saveDogProfile() async {
    if (_nameController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('강아지 이름을 입력해주세요!')),
      );
      return;
    }

    final String baseUrl = dotenv.get('BASE_URL');
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

  Future<void> _deleteDogProfile() async {
    if (!_isUpdating || widget.dogProfile == null) return;

    // 삭제 확인 다이얼로그
    final bool? confirmed = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('강아지 프로필 삭제'),
          content: const Text('정말로 이 강아지 프로필을 삭제하시겠습니까?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('취소'),
            ),
            TextButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('삭제', style: TextStyle(color: Colors.red)),
            ),
          ],
        );
      },
    );

    if (confirmed != true) return;

    final String baseUrl = dotenv.get('BASE_URL');

    try {
      final response = await http.delete(
        Uri.parse('$baseUrl/dogs/${widget.dogProfile!['id']}'),
        headers: {'Content-Type': 'application/json'},
      );

      if (response.statusCode == 200) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('강아지 프로필이 삭제되었습니다!')),
          );
          Navigator.pop(context, true);
        }
      } else {
        throw Exception('강아지 프로필 삭제 실패');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('강아지 프로필 삭제 중 오류가 발생했습니다.')),
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
        title: Text(_isUpdating ? '강아지 프로필 수정' : '강아지 프로필 등록'),
        backgroundColor: AppColors.background,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
        actions: _isUpdating
            ? [
                IconButton(
                  icon: const Icon(Icons.delete, color: Colors.red),
                  onPressed: _deleteDogProfile,
                ),
              ]
            : null,
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
            const SizedBox(height: 20),
            Text(
              '이미지를 탭하여 변경',
              style: TextStyle(
                color: Colors.grey[600],
                fontSize: 14,
              ),
            ),
            const SizedBox(height: 30),
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
                onPressed: _isUpdating ? _updateDogProfile : _saveDogProfile,
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  backgroundColor: AppColors.olivegreen,
                  foregroundColor: Colors.black,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(5),
                  ),
                ),
                child: Text(_isUpdating ? '수정' : '저장'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
