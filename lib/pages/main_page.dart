import 'package:flutter/material.dart';
import '../colors.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:dangq/setting_pages/settings_page.dart';
import 'package:dangq/board/board_page.dart';
import 'photo_sharing_page.dart';
import 'package:dangq/work/work.dart';
import 'dart:async';
import 'package:dangq/calendar/calendar.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:dangq/work_list/work_list.dart';

class MainPage extends StatefulWidget {
  final String username;

  const MainPage({super.key, required this.username});

  @override
  State<MainPage> createState() => _MainPageState();
}

class _MainPageState extends State<MainPage> {
  List<Photo> _photos = [];
  bool _isLoading = true;
  int _currentPhotoIndex = 0;
  Timer? _slideTimer;
  double avgDistance = 0.0;
  int avgSteps = 0;
  double avgTimeMinutes = 0.0;
  Timer? _statsTimer; // 통계 데이터 업데이트를 위한 타이머 추가
  // 프로필 정보를 저장할 상태 변수 추가
  String? nickname;
  String? profilePicture;
  Map<String, String> _photoUserNicknames = {}; // 추가: username to nickname 매핑

  @override
  void initState() {
    super.initState();
    _loadInitialData();
    _startStatsTimer();
  }

  // 초기 데이터 로드를 위한 메서드
  Future<void> _loadInitialData() async {
    await _loadPhotos();
    await _fetchUserStats();
    await _loadProfileInfo(); // 프로필 정보는 한 번만 로드
  }

  Future<void> _loadProfileInfo() async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/users/get_nickname?username=${widget.username}'),
      );

      if (response.statusCode == 200 && mounted) {
        final jsonResponse = json.decode(response.body);
        setState(() {
          nickname = jsonResponse['nickname'] ?? '닉네임을 불러오는 중...';
          profilePicture = jsonResponse['profile_picture'] ?? '';
        });
      }
    } catch (e) {
      print('Error loading profile info: $e');
    }
  }

  void _startStatsTimer() {
    _statsTimer = Timer.periodic(const Duration(seconds: 10), (timer) {
      if (mounted) {
        _fetchUserStats();
      }
    });
  }

  @override
  void dispose() {
    _slideTimer?.cancel();
    _statsTimer?.cancel(); // 타이머 해제

    super.dispose();
  }

  final String baseUrl = dotenv.get('BASE_URL');

  Future<void> _fetchUserStats() async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/tracking/avg/${widget.username}'),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);

        if (mounted) {
          // mounted 체크 추가
          setState(() {
            avgDistance =
                double.tryParse(data['avg_distance'].toString()) ?? 0.0;
            avgSteps =
                (double.tryParse(data['avg_steps'].toString())?.toInt()) ?? 0;
            avgTimeMinutes =
                double.tryParse(data['avg_time_minutes'].toString()) ?? 0.0;
          });
        }
      } else {
        print('Failed to load user stats. Status code: ${response.statusCode}');
      }
    } catch (error) {
      print('Error fetching user stats: $error');
    }
  }

  Future<Map<String, String>> _fetchProfileInfo(String username) async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/users/get_nickname?username=$username'),
      );

      if (response.statusCode == 200) {
        final jsonResponse = json.decode(response.body);
        return {
          'nickname': jsonResponse['nickname'] ?? '닉네임을 불러오는 중...',
          'profile_picture': jsonResponse['profile_picture'] ?? '',
        };
      } else {
        throw Exception('프로필 정보 불러오기 실패');
      }
    } catch (e) {
      throw Exception('프로필 정보 불러오기 실패: $e');
    }
  }

  Future<void> _loadPhotos() async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/photos/${widget.username}'),
      );

      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(response.body);
        setState(() {
          _photos = data.map((photo) => Photo.fromJson(photo)).toList();
          _isLoading = false;
        });

        // 각 사진 사용자의 닉네임 로드
        for (var photo in _photos) {
          _loadPhotoUserNickname(photo.username);
        }

        _startSlideShow();
      }
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
    }
  }

  // 사진 사용자의 닉네임을 로드하는 함수 추가
  Future<void> _loadPhotoUserNickname(String username) async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/users/get_nickname?username=$username'),
      );

      if (response.statusCode == 200 && mounted) {
        final jsonResponse = json.decode(response.body);
        setState(() {
          _photoUserNicknames[username] =
              jsonResponse['nickname'] ?? '알 수 없는 사용자';
        });
      }
    } catch (e) {
      print('Error loading photo user nickname: $e');
    }
  }

  void _startSlideShow() {
    if (_photos.isEmpty) return;

    _slideTimer?.cancel();
    _slideTimer = Timer.periodic(const Duration(seconds: 5), (timer) {
      if (mounted && _photos.isNotEmpty) {
        setState(() {
          _currentPhotoIndex = (_currentPhotoIndex + 1) % _photos.length;
        });
      }
    });
  }

  Future<void> _deletePhoto(int photoId) async {
    try {
      final response = await http.delete(
        Uri.parse('$baseUrl/photos/$photoId'),
        body: {'username': widget.username},
      );
      if (response.statusCode == 200) {
        _loadPhotos();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('사진이 삭제되었습니다')),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('사진 삭제에 실패했습니다')),
      );
    }
  }

  //UI 전체 구성
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Scaffold(
        backgroundColor: AppColors.background,
        appBar: _buildAppBar(context), //앱바 전체
        body: _buildBody(context), //바디 전체
      ),
    );
  }

  Widget _buildProfileSection() {
    return Row(
      children: [
        Container(
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(
              color: AppColors.lightgreen,
              width: 1,
            ),
          ),
          child: CircleAvatar(
            radius: 25,
            backgroundColor: Colors.grey[300],
            backgroundImage:
                profilePicture != null && profilePicture!.isNotEmpty
                    ? NetworkImage(profilePicture!)
                    : null,
            child: profilePicture == null || profilePicture!.isEmpty
                ? const Icon(
                    Icons.face,
                    color: Colors.grey,
                    size: 50,
                  )
                : null,
          ),
        ),
        const SizedBox(width: 14),
        Text(
          nickname ?? '닉네임을 불러오는 중...',
          style: const TextStyle(
            color: Colors.black,
            fontSize: 20,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }

  // 앱바 전체 구성
  PreferredSizeWidget _buildAppBar(BuildContext context) {
    return AppBar(
      elevation: 0,
      toolbarHeight: MediaQuery.of(context).size.height * 0.1,
      backgroundColor: Colors.transparent,
      flexibleSpace: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 5),
          child: Align(
            alignment: Alignment.bottomCenter,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                _buildProfileSection(), // 프로필 섹션 추가
                IconButton(
                  icon: const Icon(Icons.settings),
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) =>
                            SettingsPage(username: widget.username),
                      ),
                    ).then((_) {
                      // 설정 페이지에서 돌아올 때 프로필 정보만 다시 로드
                      _loadProfileInfo();
                    });
                  },
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // 바디 부분 전체 구성
  Widget _buildBody(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 18),
      child: Column(
        children: [
          const SizedBox(height: 20),
          _buildPetIconsContainer(context), //발자국 아이콘 있는 상단 박스
          const Spacer(flex: 1),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14),
            child: Column(
              children: [
                _buildIconButtonRow(), //아이콘 중간 박스 (캘린더, 게시판, 사진공유, 산책)
                const SizedBox(height: 30),
                _buildStatsContainer(context), //산책 데이터가 있는 하단 박스
              ],
            ),
          ),
          const Spacer(flex: 1),
        ],
      ),
    );
  }

/* 제일 위의 박스 */
  // 발자국 아이콘들을 포함하는 상단 컨테이너 구성
  Widget _buildPetIconsContainer(BuildContext context) {
    return Container(
      width: double.infinity,
      height: MediaQuery.of(context).size.height * 0.4,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(5),
        border: Border.all(color: AppColors.green, width: 2),
        boxShadow: [
          BoxShadow(
            //그림자
            color: AppColors.workDSTGray.withOpacity(0.3),
            spreadRadius: 2,
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _photos.isEmpty
              ? Stack(children: _buildPetIcons()) //사진이 없으면 발자국 아이콘 생성
              : Stack(
                  fit: StackFit.expand,
                  children: [
                    AnimatedSwitcher(
                      duration: const Duration(milliseconds: 500),
                      child: Image.network(
                        _photos[_currentPhotoIndex].photoUrl,
                        key: ValueKey(_currentPhotoIndex),
                        fit: BoxFit.cover, // 사진 중간에서 여백 없이 확대
                        width: double.infinity,
                        height: double.infinity,
                        loadingBuilder: (context, child, progress) {
                          if (progress == null) return child;
                          return Center(
                            child: CircularProgressIndicator(
                              value: progress.expectedTotalBytes != null
                                  ? progress.cumulativeBytesLoaded /
                                      progress.expectedTotalBytes!
                                  : null,
                            ),
                          );
                        },
                      ),
                    ),
                    // 사진 정보 오버레이
                    Positioned(
                      bottom: 0,
                      left: 0,
                      right: 0,
                      child: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.bottomCenter,
                            end: Alignment.topCenter,
                            colors: [
                              Colors.black.withOpacity(0.7),
                              Colors.transparent,
                            ],
                          ),
                        ),
                        child: Text(
                          '${_photoUserNicknames[_photos[_currentPhotoIndex].username] ?? '로딩 중...'}님의 사진',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                          ),
                        ),
                      ),
                    ),
                    if (_photos.length > 1) ...[
                      Positioned(
                        left: 0,
                        top: 0,
                        bottom: 0,
                        child: IconButton(
                          icon: const Icon(Icons.chevron_left),
                          onPressed: () {
                            setState(() {
                              _currentPhotoIndex =
                                  (_currentPhotoIndex - 1 + _photos.length) %
                                      _photos.length;
                            });
                          },
                        ),
                      ),
                      Positioned(
                        right: 0,
                        top: 0,
                        bottom: 0,
                        child: IconButton(
                          icon: const Icon(Icons.chevron_right),
                          onPressed: () {
                            setState(() {
                              _currentPhotoIndex =
                                  (_currentPhotoIndex + 1) % _photos.length;
                            });
                          },
                        ),
                      ),
                    ],
                  ],
                ),
    );
  }

  // 발자국 아이콘들의 위치를 정의하고 생성
  List<Widget> _buildPetIcons() {
    // 발자국 아이콘들의 위치 정보
    final List<Map<String, double>> positions = [
      {'top': 30, 'left': 25},
      {'top': 40, 'left': 125},
      {'top': 120, 'left': 85},
      {'top': 130, 'left': 185},
      {'top': 210, 'left': 135},
      {'top': 220, 'left': 245},
    ];

    // 각 위치에 발자국 아이콘을 생성하여 반환
    return positions.map((position) {
      return Positioned(
        top: position['top'],
        left: position['left'],
        child: Transform.rotate(
          //발바닥 아이콘 30도 회전
          angle: -30 * 3.14159 / 180,
          child: Icon(
            Icons.pets,
            size: 55,
            color: AppColors.mainPink,
          ),
        ),
      );
    }).toList();
  }

/* 중간의 아이콘들 */
  // 4개의 기능 버튼을 포함하는 행 구성
  Widget _buildIconButtonRow() {
    return SizedBox(
      width: double.infinity,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          _buildIconButton("캘린더", Icons.calendar_month, AppColors.mainYellow),
          _buildIconButton("게시판", Icons.assignment, AppColors.mainPink),
          _buildIconButton("사진 공유", Icons.camera_alt, AppColors.mainBlue),
          _buildIconButton("산책", Icons.forum, AppColors.olivegreen),
        ],
      ),
    );
  }

  // 아이콘과 라벨을 포함하는 버튼 생성
  Widget _buildIconButton(String label, IconData icon, Color color) {
    return SizedBox(
      width: 70,
      child: Column(
        children: [
          InkWell(
            onTap: () => _handleIconButtonTap(label),
            child: Container(
              width: 60,
              height: 60,
              decoration: BoxDecoration(
                color: color,
                borderRadius: BorderRadius.circular(15),
              ),
              child: Icon(icon, color: Colors.black, size: 32),
            ),
          ),
          const SizedBox(height: 10),
          Text(
            label,
            style: const TextStyle(fontSize: 14),
            textAlign: TextAlign.center,
          )
        ],
      ),
    );
  }

//아이콘 버튼 생성
  void _handleIconButtonTap(String label) {
    switch (label) {
      case "캘린더":
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => CalendarPage(username: widget.username),
          ),
        );
        break;
      case "게시판":
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => BoardPage(username: widget.username),
          ),
        );
        break;
      case "사진 공유":
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => PhotoSharingPage(username: widget.username),
          ),
        ).then((_) => _loadPhotos());
        break;
      case "산책":
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => Work(username: widget.username),
          ),
        );
        break;
    }
  }

/* 제일 밑의 박스 */
  // 통계 정보의 세로 선 위젯
  Widget _buildVerticalLine() {
    return Container(
      width: 2,
      height: 50,
      color: AppColors.lightgreen,
    );
  }

  // 통계 정보의 아이콘과 수치 위젯
  Widget _buildStatItem(
      IconData icon, String value, String unit, Color iconColor) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 2,
          height: 40, // 높이 조정
          color: AppColors.lightgreen,
        ),
        const SizedBox(width: 10), // 간격 조정
        Icon(icon, size: 24, color: iconColor), // 아이콘 크기 조정
        const SizedBox(width: 10),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              value,
              style: const TextStyle(
                fontSize: 16, // 글자 크기 조정
                fontWeight: FontWeight.bold,
                color: Colors.black,
              ),
            ),
            Text(
              unit,
              style: const TextStyle(
                fontSize: 12, // 글자 크기 조정
                color: Colors.black,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildStatsContainer(BuildContext context) {
    // 이동 거리(Km로 변환)
    final double distanceInKm = avgDistance / 1000.0;

    // 시간(Hour로 변환)
    final int hours = (avgTimeMinutes / 60).floor();
    final int minutes = (avgTimeMinutes % 60).floor();
    final int seconds = ((avgTimeMinutes * 60) % 60).floor();

    // 2자리로 포맷
    final String timeFormatted =
        "${hours.toString().padLeft(2, '0')}:${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}";

    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => WorkList(username: widget.username),
          ),
        ).then((_) {
          // WorkList 페이지에서 돌아왔을 때 데이터 새로고침
          _fetchUserStats();
        });
      },
      child: Container(
        width: double.infinity,
        height: MediaQuery.of(context).size.height * 0.2,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(5),
          border: Border.all(color: AppColors.green, width: 2),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            Expanded(
              child: Padding(
                padding: const EdgeInsets.only(left: 35),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildStatItem(
                      Icons.directions_run,
                      avgSteps.toStringAsFixed(0),
                      "걸음",
                      const Color.fromARGB(255, 239, 150, 55),
                    ),
                    const SizedBox(height: 25),
                    _buildStatItem(
                      Icons.local_fire_department,
                      distanceInKm.toStringAsFixed(3),
                      "Km",
                      const Color.fromARGB(255, 228, 77, 66),
                    ),
                  ],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.only(right: 25),
              child: Container(
                width: MediaQuery.of(context).size.width * 0.35,
                height: MediaQuery.of(context).size.width * 0.35,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.grey[200],
                  border: Border.all(
                    color: Colors.green,
                    width: 4,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.3),
                      blurRadius: 8,
                      spreadRadius: 0.5,
                      offset: const Offset(4, 4),
                    ),
                  ],
                ),
                child: Center(
                  child: Text(
                    timeFormatted,
                    style: const TextStyle(
                      color: Colors.black,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// Photo 클래스 추가
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
