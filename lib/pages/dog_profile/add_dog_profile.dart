import 'package:dangq/colors.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:io';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter/rendering.dart';

class EditDogProfilePage extends StatefulWidget {
  final String username;
  final Map<String, dynamic>? dogProfile;

  const EditDogProfilePage({
    super.key,
    required this.username,
    this.dogProfile,
  });

  @override
  _EditDogProfilePageState createState() => _EditDogProfilePageState();
}

class _EditDogProfilePageState extends State<EditDogProfilePage> {
  final TextEditingController _nameController = TextEditingController();
  String? _dogImageUrl;
  File? _imageFile;
  bool _isUpdating = false;

  @override
  void initState() {
    super.initState();
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
          const SnackBar(content: Text('기본 반려견 이미지로 되돌렸습니다!')),
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
        const SnackBar(content: Text('반려견 이름을 입력해주세요!')),
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

      // 반려견 프로필 업데이트
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
          Navigator.of(context).pop(true);
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('반려견 프로필이 수정되었습니다!')),
          );
        }
      } else {
        throw Exception('반려견 프로필 수정 실패');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('반려견 프로필 수정 중 오류가 발생했습니다.')),
        );
      }
      print('오류 발생: $e');
    }
  }

  Future<void> _saveDogProfile() async {
    if (_nameController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('반려견 이름을 입력해주세요!')),
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

      // 반려견 정보 등록
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
          Navigator.of(context).pop(true);
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('반려견 프로필이 등록되었습니다!')),
          );
        }
      } else {
        throw Exception('반려견 프로필 등록 실패');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('반려견 프로필 등록 중 오류가 발생했습니다.')),
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
        return Dialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(5),
          ),
          child: Container(
            padding: EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(5),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  '삭제 확인',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                SizedBox(height: 25),
                Text('이 반려견 프로필을 삭제하시겠습니까?'),
                SizedBox(height: 20),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    TextButton(
                      child: Text(
                        '취소',
                        style: TextStyle(color: Colors.grey),
                      ),
                      onPressed: () => Navigator.of(context).pop(false),
                    ),
                    SizedBox(width: 30),
                    TextButton(
                      child: Text(
                        '삭제',
                        style: TextStyle(color: Color(0xFF4DA374)),
                      ),
                      onPressed: () => Navigator.of(context).pop(true),
                    ),
                  ],
                ),
              ],
            ),
          ),
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
          Navigator.of(context).pop(true);
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('반려견 프로필이 삭제되었습니다!')),
          );
        }
      } else {
        throw Exception('반려견 프로필 삭제 실패');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('반려견 프로필 삭제 중 오류가 발생했습니다.')),
        );
      }
      print('오류 발생: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;
    return Scaffold(
      backgroundColor: Colors.white,
      resizeToAvoidBottomInset: true,
      appBar: AppBar(
        toolbarHeight: MediaQuery.of(context).size.height * 0.07,
        title: Text(
          _isUpdating ? '반려견 프로필 수정' : '반려견 프로필 설정',
          style: const TextStyle(
            color: Colors.black,
            fontSize: 17,
            fontWeight: FontWeight.w500,
          ),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black),
          onPressed: () => Navigator.of(context).pop(),
        ),
        backgroundColor: Colors.white,
        elevation: 0,
        scrolledUnderElevation: 0,
        surfaceTintColor: Colors.transparent,
        systemOverlayStyle: SystemUiOverlayStyle.dark,
        actions: _isUpdating
            ? [
                IconButton(
                  icon: const Icon(Icons.delete, color: Colors.red),
                  onPressed: _deleteDogProfile,
                ),
              ]
            : null,
      ),
      body: Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              padding: EdgeInsets.fromLTRB(0, 0, 0, bottomInset + 20),
              child: Column(
                children: [
                  const SizedBox(height: 40),
                  GestureDetector(
                    onTap: _pickImage,
                    child: Container(
                      width: 140,
                      height: 140,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: Colors.grey[300],
                        border: Border.all(
                          color: const Color.fromARGB(255, 153, 153, 153),
                          width: 2,
                        ),
                        image: _imageFile != null
                            ? DecorationImage(
                                image: FileImage(_imageFile!),
                                fit: BoxFit.cover,
                              )
                            : (_dogImageUrl != null && _dogImageUrl!.isNotEmpty
                                ? DecorationImage(
                                    image: NetworkImage(_dogImageUrl!),
                                    fit: BoxFit.cover,
                                  )
                                : null),
                      ),
                      child: (_imageFile == null &&
                              (_dogImageUrl == null || _dogImageUrl!.isEmpty))
                          ? const Icon(
                              Icons.add_a_photo,
                              size: 70,
                              color: Color.fromARGB(255, 153, 153, 153),
                            )
                          : null,
                    ),
                  ),
                  const SizedBox(height: 30),
                  Container(
                    margin: EdgeInsets.symmetric(horizontal: 20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '이름',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        SizedBox(height: 8),
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
                                horizontal: 15,
                                vertical: 15,
                              ),
                              border: InputBorder.none,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  SizedBox(height: 100),
                ],
              ),
            ),
          ),
          Container(
            width: double.infinity,
            height: 55,
            margin: const EdgeInsets.fromLTRB(20, 0, 20, 30),
            child: ElevatedButton(
              onPressed: _isUpdating ? _updateDogProfile : _saveDogProfile,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.lightgreen,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(5),
                ),
              ),
              child: Text(
                _isUpdating ? '수정' : '저장',
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.black,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
