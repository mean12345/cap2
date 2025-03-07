import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:video_player/video_player.dart'; // video_player 패키지 추가

class CreatePostPage extends StatefulWidget {
  final String username;

  const CreatePostPage({super.key, required this.username});

  @override
  State<CreatePostPage> createState() => _CreatePostPageState();
}

class _CreatePostPageState extends State<CreatePostPage> {
  final TextEditingController _contentController = TextEditingController();
  File? _image;
  File? _video;
  VideoPlayerController? _videoController; // 비디오 컨트롤러 추가
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

  // 비디오 선택 처리
  Future<void> _pickVideo() async {
    try {
      final XFile? video = await _picker.pickVideo(source: ImageSource.gallery);
      if (video != null) {
        setState(() {
          _video = File(video.path); // 비디오 파일을 선택
          _videoController = VideoPlayerController.file(_video!)
            ..initialize().then((_) {
              setState(() {});
            });
        });
      }
    } catch (e) {
      print('Error picking video: $e');
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
      String? videoUrl; // 비디오 URL 변수 추가
      final String baseUrl = dotenv.get('BASE_URL');

      // 이미지 업로드
      // 백엔드 필드 이름에 맞게 수정
      if (_image != null || _webImage != null) {
        var request = http.MultipartRequest(
          'POST',
          Uri.parse('$baseUrl/posts/upload'),
        );

        if (kIsWeb) {
          request.files.add(
            http.MultipartFile.fromBytes(
              'image', // 백엔드 필드 이름 확인
              _webImage!,
              filename: 'image.jpg',
            ),
          );
        } else {
          var imageStream = http.ByteStream(_image!.openRead());
          var length = await _image!.length();
          var multipartFile = http.MultipartFile(
            'image', // 백엔드 필드 이름 확인
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

// 비디오 업로드
      if (_video != null) {
        var videoRequest = http.MultipartRequest(
          'POST',
          Uri.parse('$baseUrl/posts/uploadVideo'),
        );

        var videoStream = http.ByteStream(_video!.openRead());
        var videoLength = await _video!.length();
        var multipartVideo = http.MultipartFile(
          'video', // 백엔드 필드 이름 확인
          videoStream,
          videoLength,
          filename: 'video.mp4',
        );
        videoRequest.files.add(multipartVideo);

        var videoStreamedResponse = await videoRequest.send();
        var videoResponse =
            await http.Response.fromStream(videoStreamedResponse);

        if (videoResponse.statusCode == 200) {
          videoUrl = json.decode(videoResponse.body)['url'];
        } else {
          throw Exception('비디오 업로드 실패');
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
          'video_url': videoUrl, // 비디오 URL 추가
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
      backgroundColor: Colors.white, // 배경색을 흰색으로 설정
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
                    ? Color.fromARGB(255, 128, 128, 128) // 비활성화 시 회색
                    : Color.fromARGB(255, 0, 0, 0), // 활성화 시 검정색
                fontWeight: FontWeight.bold,
              ),
            ),
            onPressed: _isUploading ? null : _createPost, // 업로드 중이면 클릭 불가
          ),
        ],
      ),
      body: Column(
        // Column으로 변경
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            // 글쓰기 영역을 확장하여 공간을 차지하게 함
            child: SingleChildScrollView(
              // 스크롤 가능하도록 변경
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 입력 필드 영역
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
                  // 동영상 미리보기 영역
                  if (_video != null)
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16.0, vertical: 8.0),
                      child: Container(
                        width: 80, // 비디오 미리보기의 너비를 작게 설정
                        height: 80, // 비디오 미리보기의 높이를 작게 설정
                        child: _videoController != null &&
                                _videoController!.value.isInitialized
                            ? AspectRatio(
                                aspectRatio: 1 / 1, // 1:1 비율로 설정
                                child: FittedBox(
                                  fit: BoxFit.cover, // 비디오가 잘리지 않도록 설정
                                  child: VideoPlayer(_videoController!),
                                ),
                              )
                            : const Center(
                                child: CircularProgressIndicator(),
                              ),
                      ),
                    ),
                  // 이미지 미리보기 영역
                  if (_image != null)
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16.0, vertical: 8.0),
                      child: Stack(
                        alignment: Alignment.topRight, // X 버튼 위치 조정
                        children: [
                          SingleChildScrollView(
                            // 스크롤 가능하도록 추가
                            child: Container(
                              width: double.infinity,
                              child: Image.file(
                                File(_image!.path),
                                fit: BoxFit.contain, // 이미지 비율 유지
                              ),
                            ),
                          ),
                          // 회색 사각형과 X 버튼 추가
                          Container(
                            padding: const EdgeInsets.all(4.0), // 여백 추가
                            decoration: BoxDecoration(
                              color: const Color.fromARGB(255, 39, 39, 39)
                                  .withOpacity(0.5), // 회색 배경
                              shape: BoxShape.rectangle, // 원형으로 설정
                            ),
                            child: IconButton(
                              icon: const Icon(Icons.close, color: Colors.red),
                              iconSize: 40.0, // X 버튼
                              onPressed: () {
                                setState(() {
                                  _image = null; // 이미지 삭제
                                });
                              },
                            ),
                          ),
                        ],
                      ),
                    ),
                  const SizedBox(height: 20), // 여백 추가
                ],
              ),
            ),
          ),
          // 사진 및 동영상 아이콘 영역
          Container(
            height: 80.0,
            padding: const EdgeInsets.all(8.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                // 이미지 영역
                SizedBox(
                  width: 100, // 각 영역의 너비를 고정
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.image, size: 36.0),
                        onPressed: _image == null && _video == null
                            ? _pickImage
                            : null, // 이미지가 없고 비디오도 없을 때만 이미지 선택 가능
                      ),
                    ],
                  ),
                ),
                // 비디오 영역
                SizedBox(
                  width: 100, // 각 영역의 너비를 고정
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.video_collection, size: 36.0),
                        onPressed: _video == null && _image == null
                            ? _pickVideo
                            : null, // 비디오가 없고 이미지도 없을 때만 비디오 선택 가능
                      ),
                      if (_video != null)
                        IconButton(
                          icon: const Icon(Icons.delete,
                              size: 24.0, color: Colors.red),
                          onPressed: () {
                            setState(() {
                              _video = null;
                              _videoController?.dispose();
                            });
                          },
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20), // 여백 추가
        ],
      ),
    );
  }

  @override
  void dispose() {
    _contentController.dispose();
    _videoController?.dispose(); // 비디오 컨트롤러 정리
    super.dispose();
  }
}
