import 'package:flutter/material.dart';
import 'package:dangq/colors.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'dart:io';
import 'package:image_picker/image_picker.dart';

class Add_dog extends StatefulWidget {
  final String username;

  const Add_dog({
    super.key,
    required this.username,
  });

  @override
  State<Add_dog> createState() => _Add_dogState();
}

class _Add_dogState extends State<Add_dog> {
  late TextEditingController _nameController;
  File? _imageFile;
  bool _isLoading = false;
  final ImagePicker _picker = ImagePicker();

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController();
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    final XFile? pickedFile =
        await _picker.pickImage(source: ImageSource.gallery);
    if (pickedFile != null) {
      setState(() {
        _imageFile = File(pickedFile.path);
      });
    }
  }

  Future<void> _saveDogProfile() async {
    if (_nameController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('강아지 이름을 입력해주세요')),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      final String baseUrl = dotenv.get('BASE_URL');
      var request =
          http.MultipartRequest('POST', Uri.parse('$baseUrl/dogs/add_dog'));

      request.fields['username'] = widget.username;
      request.fields['name'] = _nameController.text;

      if (_imageFile != null) {
        request.files.add(await http.MultipartFile.fromPath(
          'image',
          _imageFile!.path,
        ));
      }

      final response = await request.send();
      final responseString = await response.stream.bytesToString();

      if (response.statusCode == 200) {
        if (mounted) {
          Navigator.pop(context);
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('강아지 프로필이 저장되었습니다')),
          );
        }
      } else {
        throw Exception('Failed to save dog profile');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('프로필 저장 중 오류가 발생했습니다')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      resizeToAvoidBottomInset: true, // 키보드가 나타날 때 자동으로 조절
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
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              child: Column(
                children: [
                  const SizedBox(height: 80),
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
                            : null,
                      ),
                      child: _imageFile == null
                          ? const Icon(
                              Icons.add_a_photo,
                              size: 70,
                              color: Color.fromARGB(255, 153, 153, 153),
                            )
                          : null,
                    ),
                  ),
                  SizedBox(height: 30), // 동그라미와 텍스트 필드 사이 간격

                  //이름 텍스트 및 텍스트 상자
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
                            autofocus: false, // 자동 포커스 비활성화
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
          Container(
            width: double.infinity,
            height: 55,
            margin: const EdgeInsets.fromLTRB(20, 0, 20, 30),
            child: ElevatedButton(
              onPressed: _isLoading ? null : _saveDogProfile,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.lightgreen,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(5),
                ),
              ),
              child: _isLoading
                  ? const CircularProgressIndicator()
                  : const Text(
                      '저장하기',
                      style: TextStyle(
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
