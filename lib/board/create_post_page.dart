import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter_dotenv/flutter_dotenv.dart';

class CreatePostPage extends StatefulWidget {
  final String username;

  const CreatePostPage({super.key, required this.username});

  @override
  State<CreatePostPage> createState() => _CreatePostPageState();
}

class _CreatePostPageState extends State<CreatePostPage> {
  final TextEditingController _contentController = TextEditingController();
  File? _image;
  final ImagePicker _picker = ImagePicker();
  bool _isUploading = false;
  final TextEditingController _controller = TextEditingController();
  Uint8List? _webImage;
  XFile? pickedImage;

  // 이미지 선택 처리
  Future<void> _pickImage() async {
    final XFile? image = await _picker.pickImage(
      source: ImageSource.gallery,
    );
    if (image != null) {
      pickedImage = image;

      if (kIsWeb) {
        // 웹 환경에서 이미지 처리
        var bytes = await image.readAsBytes();
        setState(() {
          _webImage = bytes;
          _image = null; // 파일이 아닌 이미지 데이터를 웹용으로 사용
        });
      } else {
        // 모바일 환경에서 이미지 처리
        setState(() {
          _image = File(image.path);
          _webImage = null; // 모바일에서는 웹 이미지를 사용하지 않음
        });
      }
    }
  }

  // 게시글 작성 처리
  Future<void> _createPost() async {
    if (_contentController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('내용을 입력해주세요')),
      );
      return;
    }

    setState(() {
      _isUploading = true;
    });

    try {
      String? imageUrl;
      final String baseUrl = dotenv.get('BASE_URL');

      // 이미지 업로드
      if (_image != null || _webImage != null) {
        var request = http.MultipartRequest(
          'POST',
          Uri.parse('$baseUrl/posts/upload'),
        );

        if (kIsWeb) {
          request.files.add(
            http.MultipartFile.fromBytes(
              'image',
              _webImage!,
              filename: 'image.jpg',
            ),
          );
        } else {
          var imageStream = http.ByteStream(_image!.openRead());
          var length = await _image!.length();
          var multipartFile = http.MultipartFile(
            'image',
            imageStream,
            length,
            filename: 'image.jpg',
          );
          request.files.add(multipartFile);
        }

        var streamedResponse = await request.send();
        var response = await http.Response.fromStream(streamedResponse);

        if (response.statusCode == 200) {
          imageUrl = json.decode(response.body)['url'];
        }
      }

      // 게시글 작성
      final response = await http.post(
        Uri.parse('$baseUrl/posts'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'username': widget.username,
          'content': _contentController.text,
          'image_url': imageUrl,
        }),
      );

      if (response.statusCode == 201) {
        if (mounted) {
          Navigator.pop(context, true);
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('게시글이 작성되었습니다')),
          );
        }
      } else {
        throw Exception('게시글 작성 실패');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('게시글 작성에 실패했습니다')),
        );
      }
    } finally {
      setState(() {
        _isUploading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      resizeToAvoidBottomInset: false,
      appBar: AppBar(
        scrolledUnderElevation: 0,
        backgroundColor: Colors.white,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () {
            Navigator.pop(context);
          },
        ),
        title: const Icon(Icons.edit),
        actions: [
          IconButton(
            icon: Text(
              '완료',
              style: TextStyle(
                color: _isUploading
                    ? Color.fromARGB(255, 128, 128, 128)
                    : Color.fromARGB(255, 0, 0, 0),
                fontWeight: FontWeight.bold,
              ),
            ),
            onPressed: _isUploading ? null : _createPost,
          ),
        ],
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.all(16.0),
                    child: TextField(
                      controller: _contentController,
                      decoration: const InputDecoration(
                        hintText: '멤버들과 공유하고 싶은 소식을 남겨보세요',
                        border: InputBorder.none,
                      ),
                      maxLines: null,
                    ),
                  ),
                  if (_image != null)
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16.0, vertical: 8.0),
                      child: Stack(
                        alignment: Alignment.topRight,
                        children: [
                          SingleChildScrollView(
                            child: Container(
                              width: double.infinity,
                              child: Image.file(
                                File(_image!.path),
                                fit: BoxFit.contain,
                              ),
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.all(4.0),
                            decoration: BoxDecoration(
                              color: const Color.fromARGB(255, 39, 39, 39)
                                  .withOpacity(0.5),
                              shape: BoxShape.rectangle,
                            ),
                            child: IconButton(
                              icon: const Icon(Icons.close, color: Colors.red),
                              iconSize: 40.0,
                              onPressed: () {
                                setState(() {
                                  _image = null;
                                });
                              },
                            ),
                          ),
                        ],
                      ),
                    ),
                  const SizedBox(height: 20),
                ],
              ),
            ),
          ),
          Container(
            height: 80.0,
            padding: const EdgeInsets.all(8.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                IconButton(
                  icon: const Icon(Icons.image, size: 36.0),
                  onPressed: _image == null ? _pickImage : null,
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _contentController.dispose();
    super.dispose();
  }
}
