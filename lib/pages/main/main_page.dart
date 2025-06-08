import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:dangq/colors.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:dangq/setting_pages/settings_page.dart';
import 'package:dangq/board/board_page.dart';
import 'package:dangq/work/walk_choose.dart';
import 'package:dangq/calendar/calendar.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:dangq/work_list/work_list.dart';
import 'package:dangq/pages/dog_profile/add_dog_profile.dart';
import 'package:geocoding/geocoding.dart';
import 'package:geolocator/geolocator.dart';

class MainPage extends StatefulWidget {
  final String username;
  const MainPage({Key? key, required this.username}) : super(key: key);

  @override
  State<MainPage> createState() => _MainPageState();
}

class _MainPageState extends State<MainPage> {
  String nickname = '';
  List<Map<String, dynamic>> dogProfiles = [];
  int _currentPhotoIndex = 0;
  bool _isLoading = true;

  // 날씨 상태
  String location = '위치 불러오는 중...';
  String temperature = '--';
  String dustStatus = '정보없음';
  String precipitation = '--';

  final String baseUrl = dotenv.get('BASE_URL');

  @override
  void initState() {
    super.initState();
    _loadProfile();
    _fetchDogs();
    _fetchWeather();
  }

  Future<void> _loadProfile() async {
    try {
      final res = await http.get(
        Uri.parse('$baseUrl/users/get_nickname?username=${widget.username}'),
      );
      if (res.statusCode == 200 && mounted) {
        final j = json.decode(res.body);
        setState(() {
          nickname = (j['nickname'] as String?) ?? '';
        });
      }
    } catch (_) {}
  }

  Future<void> _fetchDogs() async {
    setState(() => _isLoading = true);
    try {
      final res = await http.get(
        Uri.parse('$baseUrl/dogs/get_dogs?username=${widget.username}'),
      );
      if (res.statusCode == 200) {
        final List list = json.decode(res.body);
        setState(() {
          dogProfiles = list.map((e) => {
                'id': e['id'],
                'dog_name': (e['name'] as String?) ?? '',
                'image_url': (e['imageUrl'] as String?) ?? '',
              }).toList();
          _currentPhotoIndex = 0;
        });
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('반려견 정보를 불러오는 데 실패했습니다.')),
        );
      }
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _fetchWeather() async {
    try {
      final key = dotenv.env['OPENWEATHER_API_KEY'];
      if (key == null) return;

      if (await Geolocator.checkPermission() == LocationPermission.denied) {
        await Geolocator.requestPermission();
      }
      final pos = await Geolocator.getCurrentPosition();
      final pms = await placemarkFromCoordinates(pos.latitude, pos.longitude);
      if (pms.isNotEmpty) {
        final p = pms.first;
        setState(() {
          location = '${p.administrativeArea} ${p.locality} ${p.subLocality}';
        });
      }

      final wRes = await http.get(Uri.parse(
          'https://api.openweathermap.org/data/2.5/weather?lat=${pos.latitude}&lon=${pos.longitude}&appid=$key&units=metric&lang=kr'));
      if (wRes.statusCode == 200) {
        final w = json.decode(wRes.body);
        setState(() {
          temperature = w['main']['temp'].toStringAsFixed(1);
          precipitation = (w['rain']?['1h'] ?? 0).toString();
        });
      }

      final aRes = await http.get(Uri.parse(
          'https://api.openweathermap.org/data/2.5/air_pollution?lat=${pos.latitude}&lon=${pos.longitude}&appid=$key'));
      if (aRes.statusCode == 200) {
        final a = json.decode(aRes.body);
        final pm25 = a['list'][0]['components']['pm2_5'];
        setState(() {
          dustStatus = pm25 <= 15
              ? '좋음'
              : pm25 <= 35
                  ? '보통'
                  : pm25 <= 75
                      ? '나쁨'
                      : '매우나쁨';
        });
      }
    } catch (_) {}
  }

  Future<void> _navigateToDogProfile() async {
    final result = await Navigator.push<bool?>(
      context,
      MaterialPageRoute(
        builder: (_) => EditDogProfilePage(
          username: widget.username,
          dogProfile:
              dogProfiles.isNotEmpty ? dogProfiles[_currentPhotoIndex] : null,
        ),
      ),
    );
    if (result == true && mounted) {
      _fetchDogs();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          // 배경 반반
          Column(
            children: [
              Expanded(flex: 1, child: Container(color: const Color(0xFFB1D09F))),
              Expanded(flex: 1, child: Container(color: Colors.white)),
            ],
          ),

          // 메인 컨텐츠 - 스크롤 제거하고 Column으로 변경
          SafeArea(
            child: Column(
              children: [
                // 앱바 영역
                SizedBox(
                  height: kToolbarHeight,
                  child: Row(
                    children: [
                      _buildProfileAvatar(),
                      Expanded(
                        child: Text(
                          nickname.isNotEmpty ? nickname : '로딩 중...',
                          style: const TextStyle(
                              color: Colors.black,
                              fontWeight: FontWeight.w500,
                              fontSize: 14),
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.settings, color: Colors.black),
                        onPressed: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => SettingsPage(username: widget.username),
                          ),
                        ).then((_) {
                          _loadProfile();
                          _fetchDogs();
                        }),
                      ),
                    ],
                  ),
                ),
                
                // 위치
                _buildLocation(),
                const SizedBox(height: 4),
                
                // 날씨 카드
                _buildWeatherCard(),
                const SizedBox(height: 8),
                
                // 프로필 타일 - 크기 줄임
                Expanded(
                  flex: 3,
                  child: _buildProfileTile(),
                ),
                const SizedBox(height: 8),
                
                // 산책 버튼
                _buildWalkButton(),
                const SizedBox(height: 8),
                
                // 하단 네비게이션
                _buildBottomNav(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProfileAvatar() => Padding(
        padding: const EdgeInsets.all(8),
        child: GestureDetector(
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => SettingsPage(username: widget.username),
            ),
          ),
          child: CircleAvatar(
            radius: 16, // 크기 줄임
            backgroundColor:
                dogProfiles.isNotEmpty ? Colors.white : Colors.orange[200],
            backgroundImage: (dogProfiles.isNotEmpty &&
                    dogProfiles[_currentPhotoIndex]['image_url']
                        .toString()
                        .isNotEmpty)
                ? NetworkImage(
                    dogProfiles[_currentPhotoIndex]['image_url'])
                : null,
            child: dogProfiles.isEmpty
                ? const Icon(Icons.add, color: Colors.white, size: 16)
                : null,
          ),
        ),
      );

  Widget _buildLocation() => Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Row(
          children: [
            const Icon(Icons.location_on, color: Colors.red, size: 12),
            const SizedBox(width: 4),
            Text(location,
                style: const TextStyle(color: Colors.black, fontSize: 10)),
          ],
        ),
      );

  Widget _buildWeatherCard() => Container(
        margin: const EdgeInsets.symmetric(horizontal: 16),
        padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 10),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(6),
          boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 4)],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text('$temperature°C',
                style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w400)),
            const SizedBox(width: 12),
            const Icon(Icons.blur_on, size: 14, color: Colors.grey),
            const SizedBox(width: 2),
            Text(dustStatus,
                style: TextStyle(
                    color: _getDustColor(dustStatus),
                    fontSize: 10,
                    fontWeight: FontWeight.w500)),
            const SizedBox(width: 12),
            const Icon(Icons.water_drop, size: 14, color: Colors.blueAccent),
            const SizedBox(width: 2),
            Text('$precipitation mm',
                style: const TextStyle(
                    color: Colors.blueAccent,
                    fontSize: 10,
                    fontWeight: FontWeight.w500)),
          ],
        ),
      );

  Color _getDustColor(String status) {
    switch (status) {
      case '좋음':
        return Colors.green;
      case '보통':
        return Colors.orange;
      case '나쁨':
        return Colors.red;
      case '매우나쁨':
        return Colors.purple;
      default:
        return Colors.grey;
    }
  }

  Widget _buildProfileTile() => GestureDetector(
        onTap: _navigateToDogProfile,
        child: Container(
          margin: const EdgeInsets.symmetric(horizontal: 16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 6)],
          ),
          child: Column(
            children: [
              Expanded(
                flex: 4,
                child: ClipRRect(
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
                  child: dogProfiles.isNotEmpty &&
                          dogProfiles[_currentPhotoIndex]['image_url']
                              .toString()
                              .isNotEmpty
                      ? Image.network(
                          dogProfiles[_currentPhotoIndex]['image_url'],
                          fit: BoxFit.cover,
                          width: double.infinity,
                          errorBuilder: (c, e, st) =>
                              const Center(child: Icon(Icons.pets, size: 24, color: Colors.grey)),
                        )
                      : const Center(child: Icon(Icons.pets, size: 24, color: Colors.grey)),
                ),
              ),
              Expanded(
                flex: 1,
                child: Center(
                  child: Text(
                    dogProfiles.isNotEmpty
                        ? dogProfiles[_currentPhotoIndex]['dog_name']
                        : '프로필 추가',
                    style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
                    textAlign: TextAlign.center,
                  ),
                ),
              ),
            ],
          ),
        ),
      );

  Widget _buildWalkButton() => ElevatedButton(
        onPressed: () {
          if (dogProfiles.isEmpty) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('반려견을 먼저 등록해주세요.')),
            );
            return;
          }
          final d = dogProfiles[_currentPhotoIndex];
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => WalkChoose(
                username: widget.username,
                dogId: d['id'],
                dogName: d['dog_name'],
              ),
            ),
          );
        },
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFFB1D09F),
          foregroundColor: Colors.white,
          fixedSize: const Size(120, 32), // 크기 줄임
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        ),
        child: const Text('산책하기', style: TextStyle(fontSize: 12)),
      );

  Widget _buildBottomNav() => Container(
        color: Colors.white,
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            _navItem('캘린더', Icons.calendar_today),
            _navItem('게시판', Icons.article),
            _navItem('기록', Icons.bar_chart),
          ],
        ),
      );

  Widget _navItem(String label, IconData icon) => GestureDetector(
        onTap: () {
          switch (label) {
            case '캘린더':
              Navigator.push(context,
                  MaterialPageRoute(builder: (_) => CalendarPage(username: widget.username)));
              break;
            case '게시판':
              Navigator.push(context,
                  MaterialPageRoute(builder: (_) => BoardPage(username: widget.username)));
              break;
            case '기록':
              if (dogProfiles.isNotEmpty) {
                final d = dogProfiles[_currentPhotoIndex];
                Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (_) => WorkList(
                              username: widget.username,
                              dogId: d['id'],
                              dogName: d['dog_name'],
                            )));
              }
              break;
          }
        },
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 20, color: const Color(0xFF424242)), // 크기 줄임
            const SizedBox(height: 2),
            Text(label,
                style: const TextStyle(
                    fontSize: 10, // 크기 줄임
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF424242))),
          ],
        ),
      );
}