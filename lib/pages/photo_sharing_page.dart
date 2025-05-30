import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:path_provider/path_provider.dart';
import 'package:dio/dio.dart';
import 'package:device_info_plus/device_info_plus.dart';

class PhotoSharingPage extends StatefulWidget {
  final String username;

  const PhotoSharingPage({super.key, required this.username});

  @override
  State<PhotoSharingPage> createState() => _PhotoSharingPageState();
}

class _PhotoSharingPageState extends State<PhotoSharingPage> {
  File? _image;
  Uint8List? _webImage;
  final ImagePicker _picker = ImagePicker();
  bool _isUploading = false;
  List<Photo> _photos = [];
  bool _isLoading = true;
  Map<String, List<Photo>> _groupedPhotos = {};

  @override
  void initState() {
    super.initState();
    _loadPhotos();
  }

  final String baseUrl = dotenv.get('BASE_URL');

  Future<void> _loadPhotos() async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/photos/${widget.username}'),
      );

      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(response.body);
        setState(() {
          _photos = data.map((photo) => Photo.fromJson(photo)).toList();
          _groupPhotosByDate(); // 날짜별로 그룹화
          _isLoading = false;
        });
      } else {
        throw Exception('Failed to load photos');
      }
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('사진을 불러오는데 실패했습니다')),
        );
      }
    }
  }

  // 사진을 날짜별로 그룹화하는 함수
  void _groupPhotosByDate() {
    _groupedPhotos.clear();
    for (var photo in _photos) {
      String dateKey = photo.uploadDate
          .toLocal()
          .toString()
          .split(' ')[0]; // "YYYY-MM-DD" 형식
      if (_groupedPhotos[dateKey] == null) {
        _groupedPhotos[dateKey] = [];
      }
      _groupedPhotos[dateKey]!.add(photo);
    }
  }

  Future<void> _uploadImage() async {
    if (_image == null && _webImage == null) return;

    setState(() {
      _isUploading = true;
    });

    try {
      var request = http.MultipartRequest(
        'POST',
        Uri.parse('$baseUrl/photos'),
      );

      if (kIsWeb) {
        request.files.add(
          http.MultipartFile.fromBytes(
            'photo',
            _webImage!,
            filename: 'photo.jpg',
          ),
        );
      } else {
        var imageStream = http.ByteStream(_image!.openRead());
        var length = await _image!.length();
        var multipartFile = http.MultipartFile(
          'photo',
          imageStream,
          length,
          filename: 'photo.jpg',
        );
        request.files.add(multipartFile);
      }

      request.fields['username'] = widget.username;

      var streamedResponse = await request.send();
      var response = await http.Response.fromStream(streamedResponse);

      if (response.statusCode == 201) {
        if (mounted) {
          setState(() {
            _image = null;
            _webImage = null;
          });
          await _loadPhotos();
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('사진이 업로드되었습니다')),
          );
        }
      } else {
        throw Exception('Failed to upload image');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('사진 업로드에 실패했습니다')),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isUploading = false;
        });
      }
    }
  }

  Future<void> _pickImage() async {
    final XFile? image = await _picker.pickImage(
      source: ImageSource.gallery,
    );
    if (image != null) {
      if (kIsWeb) {
        var bytes = await image.readAsBytes();
        setState(() {
          _webImage = bytes;
          _image = null;
        });
      } else {
        setState(() {
          _image = File(image.path);
          _webImage = null;
        });
      }
    }
  }

  // 사진 삭제 시 확인 다이얼로그 추가
  Future<void> _deletePhoto(int photoId) async {
    // 삭제 확인 다이얼로그 표시
    bool? shouldDelete = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('사진을 삭제하시겠습니까?'),
          content: const Text('이 작업은 되돌릴 수 없습니다.'),
          actions: <Widget>[
            TextButton(
              onPressed: () {
                Navigator.of(context).pop(false); // 취소
              },
              child: const Text('취소'),
            ),
            TextButton(
              onPressed: () {
                Navigator.of(context).pop(true); // 확인
              },
              child: const Text('확인'),
            ),
          ],
        );
      },
    );

    // 사용자가 확인을 눌렀을 때만 삭제 실행
    if (shouldDelete ?? false) {
      try {
        final response = await http.delete(
          Uri.parse('$baseUrl/photos/$photoId'),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({'username': widget.username}),
        );

        if (response.statusCode == 200) {
          await _loadPhotos();
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('사진이 삭제되었습니다')),
            );
          }
        } else {
          final errorMessage =
              json.decode(response.body)['message'] ?? '사진 삭제에 실패했습니다';
          throw Exception(errorMessage);
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(e.toString().replaceAll('Exception: ', ''))),
          );
        }
      }
    }
  }

  // 상세보기 화면으로 이동하는 함수
  void _viewPhotoDetail(Photo photo) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => PhotoDetailPage(photo: photo),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        scrolledUnderElevation: 0,
        title: const Text('사진 공유'),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        actions: [
          if (_image != null || _webImage != null)
            IconButton(
              icon: _isUploading
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.black,
                      ),
                    )
                  : const Icon(Icons.check, color: Colors.black),
              onPressed: _isUploading ? null : _uploadImage,
            ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _pickImage,
        child: const Icon(Icons.add_photo_alternate),
      ),
      body: Container(
        color: Colors.white,
        child: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : Column(
                children: [
                  // 미리보기 이미지 추가
                  if (_image != null || _webImage != null)
                    Container(
                      margin: const EdgeInsets.all(8.0),
                      constraints: BoxConstraints(
                        maxHeight: 300, // 최대 높이 설정
                      ),
                      child: SingleChildScrollView(
                        child: _webImage != null
                            ? Image.memory(
                                _webImage!,
                                fit: BoxFit.contain,
                              )
                            : Image.file(
                                _image!,
                                fit: BoxFit.contain,
                              ),
                      ),
                    ),
                  Expanded(
                    child: ListView(
                      children: _groupedPhotos.entries.map((entry) {
                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Padding(
                              padding: const EdgeInsets.all(8.0),
                              child: Text(
                                entry.key, // 날짜
                                style: const TextStyle(
                                    fontSize: 18, fontWeight: FontWeight.bold),
                              ),
                            ),
                            GridView.builder(
                              shrinkWrap: true,
                              physics: const NeverScrollableScrollPhysics(),
                              padding: const EdgeInsets.all(8),
                              gridDelegate:
                                  const SliverGridDelegateWithFixedCrossAxisCount(
                                crossAxisCount: 3,
                                crossAxisSpacing: 8,
                                mainAxisSpacing: 8,
                              ),
                              itemCount: entry.value.length,
                              itemBuilder: (context, index) {
                                final photo = entry.value[index];
                                return GestureDetector(
                                  onTap: () => _viewPhotoDetail(photo),
                                  child: Stack(
                                    fit: StackFit.expand,
                                    children: [
                                      Image.network(
                                        photo.photoUrl,
                                        fit: BoxFit.cover,
                                      ),
                                      if (photo.username == widget.username)
                                        Positioned(
                                          top: 0,
                                          right: 0,
                                          child: Container(
                                            color:
                                                Colors.black.withOpacity(0.5),
                                            child: IconButton(
                                              icon: const Icon(
                                                Icons.delete,
                                                color: Colors.white,
                                              ),
                                              onPressed: () =>
                                                  _deletePhoto(photo.id),
                                            ),
                                          ),
                                        ),
                                    ],
                                  ),
                                );
                              },
                            ),
                          ],
                        );
                      }).toList(),
                    ),
                  ),
                ],
              ),
      ),
    );
  }
}

class Photo {
  final int id;
  final String photoUrl;
  final String username;
  final DateTime uploadDate;

  Photo({
    required this.id,
    required this.photoUrl,
    required this.username,
    required this.uploadDate,
  });

  factory Photo.fromJson(Map<String, dynamic> json) {
    return Photo(
      id: json['photo_id'],
      photoUrl: json['photo_url'],
      username: json['username'],
      uploadDate: DateTime.parse(json['upload_date']),
    );
  }
}

// 상세보기 화면
class PhotoDetailPage extends StatelessWidget {
  final Photo photo;

  const PhotoDetailPage({super.key, required this.photo});

  Future<void> _downloadImage(BuildContext context) async {
    try {
      if (kIsWeb) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('웹에서는 다운로드가 지원되지 않습니다.')),
        );
        return;
      }

      if (Platform.isAndroid) {
        // Android 버전 확인
        final androidInfo = await DeviceInfoPlugin().androidInfo;
        final androidVersion = androidInfo.version.sdkInt;

        if (androidVersion >= 33) {
          // Android 13 이상
          final status = await Permission.photos.status;
          if (status.isDenied) {
            final result = await Permission.photos.request();
            if (!result.isGranted) {
              if (context.mounted) {
                _showPermissionDialog(context);
              }
              return;
            }
          }
        } else {
          // Android 12 이하
          final status = await Permission.storage.status;
          if (status.isDenied) {
            final result = await Permission.storage.request();
            if (!result.isGranted) {
              if (context.mounted) {
                _showPermissionDialog(context);
              }
              return;
            }
          }
        }
      }

      // 진행 상태를 표시하는 다이얼로그
      if (context.mounted) {
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (BuildContext context) {
            return const Center(
              child: CircularProgressIndicator(),
            );
          },
        );
      }

      // 파일 저장 경로 설정
      String? downloadPath;
      if (Platform.isAndroid) {
        final directory = await getExternalStorageDirectory();
        if (directory != null) {
          final picturesDir = Directory('${directory.path}/Pictures');
          if (!await picturesDir.exists()) {
            await picturesDir.create(recursive: true);
          }
          downloadPath = '${picturesDir.path}/photo_${photo.id}.jpg';
        }
      } else {
        final directory = await getApplicationDocumentsDirectory();
        downloadPath = '${directory.path}/photo_${photo.id}.jpg';
      }

      if (downloadPath == null) {
        throw Exception('저장 경로를 생성할 수 없습니다.');
      }

      final Dio dio = Dio();
      await dio.download(
        photo.photoUrl,
        downloadPath,
        options: Options(
          responseType: ResponseType.bytes,
          followRedirects: false,
        ),
      );

      // 다운로드한 이미지 갤러리에 저장
      //await _saveImageToGallery(downloadPath);

      if (context.mounted) {
        Navigator.pop(context); // 프로그레스 다이얼로그 닫기
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('사진이 저장되었습니다')),
        );
      }
    } catch (e) {
      if (context.mounted) {
        Navigator.pop(context); // 프로그레스 다이얼로그 닫기
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('다운로드 실패: ${e.toString()}')),
        );
      }
    }
  }

  // Future<void> _saveImageToGallery(String downloadPath) async {
  //   if (Platform.isAndroid) {
  //     final galleryDirectory = await getExternalStorageDirectory();
  //     if (galleryDirectory != null) {
  //       final imagesDir = Directory('${galleryDirectory.path}/Pictures');
  //       final file = File(downloadPath);
  //       if (file.existsSync()) {
  //         final result = await ImageGallerySaverPlus.saveFile(file.path);
  //         if (result != null && result['isSuccess'] == true) {
  //           print('Image saved to gallery!');
  //         }
  //       }
  //     }
  //   }
  // }

  void _showPermissionDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (BuildContext context) => AlertDialog(
        title: const Text('권한 필요'),
        content:
            const Text('사진을 저장하기 위해서는 사진 및 미디어 접근 권한이 필요합니다. 설정에서 권한을 허용해주세요.'),
        actions: <Widget>[
          TextButton(
            child: const Text('취소'),
            onPressed: () => Navigator.of(context).pop(),
          ),
          TextButton(
            child: const Text('설정으로 이동'),
            onPressed: () {
              openAppSettings();
              Navigator.of(context).pop();
            },
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        scrolledUnderElevation: 0,
        title: const Text('사진 상세보기'),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
      ),
      body: Container(
        color: Colors.white,
        child: SingleChildScrollView(
          child: Column(
            children: [
              Image.network(photo.photoUrl),
              const SizedBox(height: 16),
              Text(
                '업로드한 사용자: ${photo.username}',
                style: const TextStyle(fontSize: 16),
              ),
              Text(
                '업로드일: ${photo.uploadDate.toLocal().toString().split(' ')[0]}',
                style: const TextStyle(fontSize: 14),
              ),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: () => _downloadImage(context),
                child: const Text('사진 다운로드'),
              ),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }
}
