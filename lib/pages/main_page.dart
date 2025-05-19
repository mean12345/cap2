import 'package:flutter/material.dart';
import '../colors.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:dangq/setting_pages/settings_page.dart';
import 'package:dangq/board/board_page.dart';
import 'package:dangq/work/walk_choose.dart';
import 'dart:async';
import 'package:dangq/calendar/calendar.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'add_dog_page.dart';
import 'package:dangq/work_list/work_list.dart';
import 'package:dangq/pages/dog_profile/dog_profile.dart';

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
  double avgDistance = 0.0;
  int avgSteps = 0;
  double avgTimeMinutes = 0.0;
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
            const SnackBar(content: Text('강아지 프로필을 불러오는 데 실패했습니다.')),
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

      // 404 상태 코드: 강아지 정보가 없는 경우 (정상적인 상황)
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

  Future<void> _deleteDogProfile(int dogId) async {
    try {
      final url = '$baseUrl/dogs/$dogId';
      final response = await http.delete(Uri.parse(url));

      if (response.statusCode == 200) {
        // 삭제 성공 후 목록 다시 불러오기
        try {
          await _fetchDogProfiles();

          // 현재 인덱스가 범위를 벗어나지 않도록 조정
          if (dogProfiles.isNotEmpty &&
              _currentPhotoIndex >= dogProfiles.length) {
            setState(() {
              _currentPhotoIndex = dogProfiles.length - 1;
            });
          }

          // 성공 메시지 표시
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('강아지 프로필이 삭제되었습니다.')),
            );
          }
        } catch (e) {
          // 강아지가 모두 삭제되었거나 API가 404를 반환한 경우
          setState(() {
            dogProfiles = [];
            _currentPhotoIndex = 0;
          });

          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                  content: Text('강아지 프로필이 삭제되었습니다. 더 이상 등록된 강아지가 없습니다.')),
            );
          }
        }
      } else {
        // 오류 메시지 표시
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('삭제 실패: ${response.statusCode}')),
          );
        }
      }
    } catch (e) {
      print('강아지 프로필 삭제 오류: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('강아지 프로필 삭제 중 오류가 발생했습니다.')),
        );
      }
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
      backgroundColor: AppColors.background,
      appBar: _buildAppBar(context),
      body: _buildBody(context),
    );
  }

  Widget _buildProfileSection() {
    return Row(
      children: [
        CircleAvatar(
          radius: 25,
          backgroundImage: profilePicture != null && profilePicture!.isNotEmpty
              ? NetworkImage(profilePicture!)
              : null,
          child: profilePicture == null || profilePicture!.isEmpty
              ? const Icon(Icons.face, color: Colors.grey)
              : null,
        ),
        const SizedBox(width: 14),
        Text(
          nickname ?? '닉네임을 불러오는 중...',
          style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w500),
        ),
      ],
    );
  }

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
              children: [
                _buildProfileSection(),
                IconButton(
                  icon: const Icon(Icons.settings),
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) =>
                            SettingsPage(username: widget.username),
                      ),
                    ).then((_) => _loadProfileInfo());
                  },
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildBody(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 18),
      child: Column(
        children: [
          const SizedBox(height: 20),
          _buildDogProfileSection(),
          const SizedBox(height: 20),
          _buildIconButtonRow(),
          const SizedBox(height: 20),
          _buildWalkButton(),
        ],
      ),
    );
  }

  Widget _buildWalkButton() {
    return SizedBox(
      width: 250,
      height: 50,
      child: ElevatedButton(
        onPressed: () {
          if (dogProfiles.isEmpty) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('등록된 강아지가 없습니다. 먼저 강아지를 등록해주세요.')),
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
          backgroundColor: AppColors.lightgreen,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(15),
          ),
        ),
        child: const Text(
          '산책하기',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: Colors.black,
          ),
        ),
      ),
    );
  }

  Widget _buildDogProfileSection() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (dogProfiles.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text('등록된 강아지가 없습니다.'),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) =>
                        EditDogProfilePage(username: widget.username),
                  ),
                ).then((_) => _fetchDogProfilesSafely());
              },
              child: const Text('강아지 등록하기'),
            ),
          ],
        ),
      );
    }

    // 안전하게 인덱스 범위 확인
    if (_currentPhotoIndex >= dogProfiles.length) {
      _currentPhotoIndex = dogProfiles.length - 1;
    }

    final currentDog = dogProfiles[_currentPhotoIndex];

    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            IconButton(
              icon: const Icon(Icons.arrow_back),
              onPressed: _prevDogProfile,
            ),
            Stack(
              alignment: Alignment.bottomRight,
              children: [
                InkWell(
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => DogProfile(
                          username: widget.username,
                        ),
                      ),
                    ).then((_) => _fetchDogProfilesSafely());
                  },
                  child: CircleAvatar(
                    radius: 90,
                    backgroundImage: currentDog['image_url'] != null
                        ? NetworkImage(currentDog['image_url'])
                        : null,
                    child: currentDog['image_url'] == null
                        ? const Icon(Icons.pets, size: 90)
                        : null,
                  ),
                ),
              ],
            ),
            IconButton(
              icon: const Icon(Icons.arrow_forward),
              onPressed: _nextDogProfile,
            ),
          ],
        ),
        const SizedBox(height: 10),
        Text(
          currentDog['dog_name'],
          style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 20),
      ],
    );
  }

  Widget _buildIconButtonRow() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceAround,
      children: [
        _buildIconButton("캘린더", Icons.calendar_month, AppColors.mainYellow),
        _buildIconButton("게시판", Icons.assignment, AppColors.mainPink),
        _buildIconButton("리스트", Icons.list, AppColors.olivegreen),
      ],
    );
  }

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
                  color: color, borderRadius: BorderRadius.circular(15)),
              child: Icon(icon, color: Colors.black, size: 32),
            ),
          ),
          const SizedBox(height: 10),
          Text(label, style: const TextStyle(fontSize: 14))
        ],
      ),
    );
  }

  void _handleIconButtonTap(String label) {
    // 현재 선택된 강아지 정보 가져오기
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
      case "리스트":
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
      case "산책":
        // 현재 선택된 강아지가 있는지 확인
        if (dogProfiles.isEmpty) {
          // 등록된 강아지가 없는 경우 알림 표시
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('등록된 강아지가 없습니다. 먼저 강아지를 등록해주세요.')),
          );
          return;
        }

        print('선택한 강아지: $dogName (ID: $dogId)로 산책하기');

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
