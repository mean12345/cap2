import 'package:flutter/material.dart';
import 'package:dangq/colors.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:dangq/setting_pages/settings_page.dart';
import 'package:dangq/board/board_page.dart';
import 'package:dangq/work/walk_choose.dart';
import 'dart:async';
import 'package:dangq/calendar/calendar.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:dangq/work_list/work_list.dart';
import 'package:dangq/pages/dog_profile/dog_profile.dart';
import 'package:dangq/pages/dog_profile/add_dog_profile.dart';
import 'package:flutter/services.dart';
import 'package:dangq/pages/main/dog_profile_film.dart';

class MainPage extends StatefulWidget {
  final String username;

  const MainPage({super.key, required this.username});

  @override
  State<MainPage> createState() => _MainPageState();
}

class _MainPageState extends State<MainPage> {
  bool _isLoading = true;
  int _currentPhotoIndex = 0;
  Timer? _slideTimer;
  Timer? _statsTimer;
  String? nickname;
  String? profilePicture;

  List<Map<String, dynamic>> dogProfiles = [];

  final String baseUrl = dotenv.get('BASE_URL');

  @override
  void initState() {
    super.initState();
    _loadProfileInfo();
    _fetchDogProfilesSafely();
  }

  void _fetchDogProfilesSafely() {
    _fetchDogProfiles().catchError((e) {
      // 오류가 발생하면, 목록을 빈 배열로 설정하고 UI 업데이트
      setState(() {
        dogProfiles = [];
        _currentPhotoIndex = 0;
        _isLoading = false;
      });

      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('반려견 프로필을 불러오는 데 실패했습니다.')),
          );
        }
      });
    });
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

  Future<void> _fetchDogProfiles() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final url = '$baseUrl/dogs/get_dogs?username=${widget.username}';
      print('요청 URL: $url'); // 요청 URL 확인 로그

      final response = await http.get(Uri.parse(url));
      print('응답 상태 코드: ${response.statusCode}');
      print('응답 본문: ${response.body}');

      // 404 상태 코드: 반려견 정보가 없는 경우 (정상적인 상황)
      if (response.statusCode == 404) {
        setState(() {
          dogProfiles = []; // 빈 리스트로 설정
          _currentPhotoIndex = 0;
          _isLoading = false;
        });
        return;
      }

      if (response.statusCode == 200) {
        // 응답을 직접 리스트로 파싱
        final List<dynamic> jsonResponse = json.decode(response.body);

        setState(() {
          // 각 항목을 올바른 키로 매핑
          dogProfiles = jsonResponse
              .map((dog) => {
                    'dog_name': dog['name'],
                    'image_url': dog['imageUrl'],
                    'id': dog['id'],
                  })
              .toList();

          // 프로필이 있는데 인덱스가 범위를 벗어나면 조정
          if (dogProfiles.isNotEmpty &&
              _currentPhotoIndex >= dogProfiles.length) {
            _currentPhotoIndex = dogProfiles.length - 1;
          }

          _isLoading = false;
        });
      } else {
        print('실패: ${response.statusCode}');
        setState(() {
          _isLoading = false;
        });
        throw Exception('Failed to load dog profiles');
      }
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      print('예외 발생: $e');
      rethrow;
    }
  }

  void _nextDogProfile() {
    if (dogProfiles.isEmpty) return;
    setState(() {
      _currentPhotoIndex = (_currentPhotoIndex + 1) % dogProfiles.length;
    });
  }

  void _prevDogProfile() {
    if (dogProfiles.isEmpty) return;
    setState(() {
      _currentPhotoIndex =
          (_currentPhotoIndex - 1 + dogProfiles.length) % dogProfiles.length;
    });
  }

  @override
  void dispose() {
    _slideTimer?.cancel();
    _statsTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        systemOverlayStyle: const SystemUiOverlayStyle(
          statusBarColor: Colors.white,
          statusBarIconBrightness: Brightness.dark,
          statusBarBrightness: Brightness.light,
        ),
        leadingWidth: 65,
        titleSpacing: -12,
        elevation: 0,
        backgroundColor: Colors.white,
        flexibleSpace: Container(
          decoration: const BoxDecoration(
            color: Colors.white,
          ),
        ),
        leading: SizedBox(
          width: 45,
          height: 45,
          child: Center(
            child: Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: Colors.white,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.1),
                    spreadRadius: 1,
                    blurRadius: 4,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: ClipOval(
                child: profilePicture != null && profilePicture!.isNotEmpty
                    ? Image.network(
                        profilePicture!,
                        fit: BoxFit.cover,
                        width: 38,
                        height: 38,
                      )
                    : Container(
                        width: 38,
                        height: 38,
                        color: Colors.grey[50],
                        child: const Icon(
                          Icons.person_outline,
                          color: AppColors.textSecondary,
                          size: 20,
                        ),
                      ),
              ),
            ),
          ),
        ),
        title: Padding(
          padding: const EdgeInsets.only(left: 8),
          child: Text(
            nickname ?? '닉네임을 불러오는 중...',
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w500,
              color: AppColors.textPrimary,
              letterSpacing: -0.5,
            ),
          ),
        ),
        actions: [
          Container(
            margin: const EdgeInsets.only(right: 16, top: 8, bottom: 8),
            decoration: const BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
            ),
            child: IconButton(
              icon: const Icon(
                Icons.settings,
                color: Color(0xFF9B9B9B),
                size: 30,
              ),
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) =>
                        SettingsPage(username: widget.username),
                  ),
                ).then((_) {
                  _loadProfileInfo();
                  _fetchDogProfilesSafely();
                });
              },
            ),
          ),
        ],
      ),
      body: SafeArea(
        child: Container(
          color: Colors.white,
          child: Column(
            children: [
              const SizedBox(height: 40), // 20에서 40으로 수정
              _buildDogProfileSection(),
              const SizedBox(height: 45), // 여백 조정
              _buildWalkButton(),
              const Spacer(),
              Container(
                color: Colors.white,
                padding: const EdgeInsets.only(bottom: 50),
                child: Column(
                  children: [
                    const SizedBox(height: 40),
                    _buildIconButtonRow(),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDogProfileSection() {
    if (_isLoading) {
      return const Center(
          child: CircularProgressIndicator(
        valueColor: AlwaysStoppedAnimation<Color>(AppColors.lightgreen),
      ));
    }

    if (dogProfiles.isEmpty) {
      final screenHeight = MediaQuery.of(context).size.height;
      final isSmallScreen = screenHeight < 700;

      return Container(
        padding: const EdgeInsets.symmetric(vertical: 15),
        child: GestureDetector(
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => EditDogProfilePage(
                  username: widget.username,
                ),
              ),
            ).then((_) {
              _fetchDogProfilesSafely();
              _loadProfileInfo();
            });
          },
          child: Container(
            width: MediaQuery.of(context).size.width *
                (isSmallScreen ? 0.75 : 0.8),
            height: screenHeight * (isSmallScreen ? 0.33 : 0.4),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(8),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.15),
                  spreadRadius: 1,
                  blurRadius: 8,
                  offset: const Offset(3, 3),
                ),
              ],
            ),
            child: Stack(
              children: [
                Positioned(
                  top: isSmallScreen ? 10 : 15,
                  left: isSmallScreen ? 10 : 15,
                  right: isSmallScreen ? 10 : 15,
                  bottom: isSmallScreen ? 40 : 50,
                  child: Container(
                    decoration: BoxDecoration(
                      color: Colors.grey[50],
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: const Icon(
                      Icons.pets,
                      size: 50,
                      color: AppColors.lightgreen,
                    ),
                  ),
                ),
                Positioned(
                  bottom: 0,
                  left: 0,
                  right: 0,
                  child: Container(
                    height: isSmallScreen ? 35 : 45,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: const BorderRadius.only(
                        bottomLeft: Radius.circular(8),
                        bottomRight: Radius.circular(8),
                      ),
                    ),
                    child: Center(
                      child: Text(
                        '반려견을 등록해주세요',
                        style: TextStyle(
                          fontSize: isSmallScreen ? 14 : 16,
                          fontWeight: FontWeight.w500,
                          color: AppColors.textPrimary,
                          letterSpacing: -0.5,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        // 화면 크기에 따라 동적으로 크기 조절
        final screenHeight = MediaQuery.of(context).size.height;
        final isSmallScreen = screenHeight < 700; // 작은 화면 기준

        return Container(
          height: isSmallScreen
              ? screenHeight * 0.4 // 작은 화면에서는 40%
              : screenHeight * 0.45, // 큰 화면에서는 45%
          child: PageView.builder(
            itemCount: dogProfiles.length,
            controller: PageController(
              initialPage: _currentPhotoIndex,
              viewportFraction: isSmallScreen ? 0.8 : 0.85,
            ),
            physics: const BouncingScrollPhysics(),
            onPageChanged: (index) {
              setState(() {
                _currentPhotoIndex = index;
              });
            },
            itemBuilder: (context, index) {
              final dog = dogProfiles[index];
              final imageUrl = dog['image_url'];

              return Container(
                padding: EdgeInsets.symmetric(
                  horizontal: isSmallScreen ? 8 : 10,
                ),
                child: Column(
                  children: [
                    GestureDetector(
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => DogProfile(
                              username: widget.username,
                            ),
                          ),
                        ).then((result) {
                          if (result != null &&
                              result is Map<String, dynamic>) {
                            setState(() {
                              int index = dogProfiles.indexWhere(
                                  (dog) => dog['id'] == result['dogId']);
                              if (index != -1) {
                                dogProfiles[index]['dog_name'] =
                                    result['dogName'];
                                dogProfiles[index]['image_url'] =
                                    result['imageUrl'];
                                _currentPhotoIndex = index;
                              }
                            });
                          }
                          // 항상 프로필 정보도 새로고침
                          _loadProfileInfo();
                          _fetchDogProfilesSafely();
                        });
                      },
                      child: Container(
                        width: MediaQuery.of(context).size.width *
                            (isSmallScreen ? 0.75 : 0.8),
                        height: screenHeight * (isSmallScreen ? 0.35 : 0.42),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(8),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.15),
                              spreadRadius: 1,
                              blurRadius: 8,
                              offset: const Offset(3, 3),
                            ),
                          ],
                        ),
                        child: Stack(
                          children: [
                            Positioned(
                              top: isSmallScreen ? 10 : 15,
                              left: isSmallScreen ? 10 : 15,
                              right: isSmallScreen ? 10 : 15,
                              bottom: isSmallScreen ? 40 : 50,
                              child: Container(
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: ClipRRect(
                                  borderRadius: BorderRadius.circular(4),
                                  child: imageUrl != null
                                      ? Image.network(
                                          imageUrl,
                                          fit: BoxFit.cover,
                                          errorBuilder:
                                              (context, error, stackTrace) {
                                            return Container(
                                              color: Colors.grey[50],
                                              child: const Icon(
                                                Icons.pets,
                                                size: 50,
                                                color: AppColors.lightgreen,
                                              ),
                                            );
                                          },
                                        )
                                      : Container(
                                          color: Colors.grey[50],
                                          child: const Icon(
                                            Icons.pets,
                                            size: 50,
                                            color: AppColors.lightgreen,
                                          ),
                                        ),
                                ),
                              ),
                            ),
                            Positioned(
                              bottom: 0,
                              left: 0,
                              right: 0,
                              child: Container(
                                height: isSmallScreen ? 35 : 45,
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: const BorderRadius.only(
                                    bottomLeft: Radius.circular(8),
                                    bottomRight: Radius.circular(8),
                                  ),
                                ),
                                child: Center(
                                  child: Text(
                                    dog['dog_name'] ?? '이름 없음',
                                    style: TextStyle(
                                      fontSize: isSmallScreen ? 14 : 16,
                                      fontWeight: FontWeight.w500,
                                      color: AppColors.textPrimary,
                                      letterSpacing: -0.5,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        );
      },
    );
  }

  Widget _buildWalkButton() {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(8),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            spreadRadius: 1,
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: SizedBox(
        width: 250,
        height: 50,
        child: ElevatedButton(
          onPressed: () {
            if (dogProfiles.isEmpty) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('등록된 반려견이 없습니다. 먼저 반려견을 등록해주세요.')),
              );
              return;
            }
            final currentDog = dogProfiles[_currentPhotoIndex];
            final dogId = currentDog['id'];
            final dogName = currentDog['dog_name'];

            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => WalkChoose(
                  username: widget.username,
                  dogId: dogId,
                  dogName: dogName,
                ),
              ),
            ).then((result) {
              if (result != null && result is Map<String, dynamic>) {
                setState(() {
                  int index = dogProfiles
                      .indexWhere((dog) => dog['id'] == result['dogId']);
                  if (index != -1) {
                    dogProfiles[index]['dog_name'] = result['dogName'];
                    dogProfiles[index]['image_url'] = result['imageUrl'];
                    _currentPhotoIndex = index;
                  }
                });
              }
            });
          },
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFFB1D09F),
            foregroundColor: Colors.white,
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
          ),
          child: const Text(
            '산책하기',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w500,
              color: Color.fromARGB(255, 0, 0, 0),
              letterSpacing: -0.5,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildIconButtonRow() {
    final screenHeight = MediaQuery.of(context).size.height;
    final isSmallScreen = screenHeight < 700;

    return Container(
      width: MediaQuery.of(context).size.width,
      padding: EdgeInsets.symmetric(
        horizontal: 8,
        vertical: 0,
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        mainAxisSize: MainAxisSize.max,
        children: [
          _buildIconButton("캘린더", Icons.calendar_month, AppColors.mainYellow),
          _buildIconButton("게시판", Icons.assignment, AppColors.mainPink),
          _buildIconButton(
              "산책기록", Icons.analytics_outlined, AppColors.mainBlue),
        ],
      ),
    );
  }

  Widget _buildIconButton(String label, IconData icon, Color color) {
    final screenHeight = MediaQuery.of(context).size.height;
    final isSmallScreen = screenHeight < 700;

    final iconSize = isSmallScreen ? 50.0 : 60.0;
    final containerSize = isSmallScreen ? 45.0 : 60.0;

    return SizedBox(
      width: isSmallScreen ? 70 : 80,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          InkWell(
            onTap: () => _handleIconButtonTap(label),
            child: Container(
              width: containerSize,
              height: containerSize,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(15),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.1),
                    spreadRadius: 1,
                    blurRadius: 4,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Icon(icon,
                  color: Colors.grey[600], size: isSmallScreen ? 24 : 32),
            ),
          ),
          SizedBox(height: isSmallScreen ? 6 : 10),
          Text(
            label,
            style: TextStyle(
              fontSize: isSmallScreen ? 12 : 14,
              fontWeight: FontWeight.w500,
              color: AppColors.textPrimary,
            ),
            textAlign: TextAlign.center,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  void _handleIconButtonTap(String label) {
    final currentDog = dogProfiles[_currentPhotoIndex];
    final dogId = currentDog['id'];
    final dogName = currentDog['dog_name'];

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
      case "산책기록":
        if (dogProfiles.isEmpty) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('등록된 강아지가 없습니다. 먼저 강아지를 등록해주세요.')),
          );
          return;
        }

        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => WorkList(
              username: widget.username,
              dogId: dogId,
              dogName: dogName,
            ),
          ),
        ).then((result) {
          //페이지가 닫힐 때 프로필 정보 가져와서 업데이트
          if (result != null && result is Map<String, dynamic>) {
            // 현재 프로필 업데이트
            setState(() {
              int index =
                  dogProfiles.indexWhere((dog) => dog['id'] == result['dogId']);
              if (index != -1) {
                dogProfiles[index]['dog_name'] = result['dogName'];
                dogProfiles[index]['image_url'] = result['imageUrl'];
                _currentPhotoIndex = index;
              }
            });
          }
        });
        break;
    }
  }
}
