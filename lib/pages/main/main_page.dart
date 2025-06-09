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
import 'package:dangq/work/dog_list.dart';
import 'package:dangq/pages/dog_profile/dog_profile.dart';
import 'package:dangq/pages/dog_profile/add_dog_profile.dart'; // 추가된 import

class MainPage extends StatefulWidget {
  final String username;
  final int? selectedDogId; // 선택된 강아지 ID 파라미터 추가

  const MainPage({
    Key? key,
    required this.username,
    this.selectedDogId,
  }) : super(key: key);

  @override
  State<MainPage> createState() => _MainPageState();
}

class _MainPageState extends State<MainPage> with WidgetsBindingObserver {
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
    WidgetsBinding.instance.addObserver(this);
    // 즉시 데이터 로드
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _refreshData();
      _fetchWeather();
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // 페이지가 보여질 때마다 데이터 새로고침
    _refreshData();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  // 앱이 포그라운드로 돌아올 때 호출됨
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _refreshData();
    }
  }

  // 공통 새로고침 함수 - 동시 실행으로 속도 개선
  Future<void> _refreshData() async {
    // 병렬로 실행하여 속도 향상
    final futures = <Future>[
      _loadProfile(),
      _fetchDogs(),
    ];

    await Future.wait(futures);
  }

  // 백그라운드에서 데이터를 새로고침하는 함수 (로딩 상태 없이)
  Future<void> _refreshDataInBackground() async {
    final futures = <Future>[
      _loadProfile(),
      _fetchDogsInBackground(),
    ];

    await Future.wait(futures);
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
    await _fetchDogsCore();
    setState(() => _isLoading = false);
  }

  // 백그라운드에서 강아지 데이터를 가져오는 함수 (로딩 상태 없이)
  Future<void> _fetchDogsInBackground() async {
    await _fetchDogsCore();
  }

  // 강아지 데이터 가져오기 핵심 로직
  Future<void> _fetchDogsCore() async {
    try {
      final res = await http.get(
        Uri.parse('$baseUrl/dogs/get_dogs?username=${widget.username}'),
      );
      if (res.statusCode == 200) {
        final List list = json.decode(res.body);
        final newDogProfiles = list
            .map((e) => {
                  'id': e['id'],
                  'dog_name': (e['name'] as String?) ?? '',
                  'image_url': (e['imageUrl'] as String?) ?? '',
                })
            .toList();

        setState(() {
          // 현재 선택된 강아지의 ID를 저장
          final currentSelectedDogId =
              dogProfiles.isNotEmpty && _currentPhotoIndex < dogProfiles.length
                  ? dogProfiles[_currentPhotoIndex]['id']
                  : null;

          dogProfiles = newDogProfiles;

          // 선택된 강아지 ID가 있으면 해당 인덱스로 설정
          if (widget.selectedDogId != null) {
            final selectedIndex = dogProfiles
                .indexWhere((dog) => dog['id'] == widget.selectedDogId);
            _currentPhotoIndex = selectedIndex >= 0 ? selectedIndex : 0;
          }
          // widget.selectedDogId가 없지만 기존에 선택된 강아지가 있다면 그 강아지를 유지
          else if (currentSelectedDogId != null) {
            final maintainIndex = dogProfiles
                .indexWhere((dog) => dog['id'] == currentSelectedDogId);
            _currentPhotoIndex = maintainIndex >= 0 ? maintainIndex : 0;
          }
          // 완전히 처음 로드하는 경우에만 0으로 설정
          else if (dogProfiles.isNotEmpty &&
              _currentPhotoIndex >= dogProfiles.length) {
            _currentPhotoIndex = 0;
          }
        });
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('반려견 정보를 불러오는 데 실패했습니다.')),
        );
      }
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

  // 강아지 선택 변경을 처리하는 함수
  void _updateSelectedDog(int dogId) {
    final selectedIndex = dogProfiles.indexWhere((dog) => dog['id'] == dogId);
    if (selectedIndex >= 0) {
      setState(() {
        _currentPhotoIndex = selectedIndex;
      });
    }
  }

  // 즉시 강아지 선택을 변경하는 함수 (로딩 없이)
  void _updateSelectedDogImmediately(int dogId) {
    final selectedIndex = dogProfiles.indexWhere((dog) => dog['id'] == dogId);
    if (selectedIndex >= 0) {
      setState(() {
        _currentPhotoIndex = selectedIndex;
      });
    }
  }

  // 즉시 반영을 위한 최적화된 네비게이션 함수
  Future<void> _navigateAndRefresh(Widget page) async {
    final result =
        await Navigator.push(context, MaterialPageRoute(builder: (_) => page));

    if (mounted && result is Map && result['selectedDogId'] != null) {
      // 선택된 강아지 ID가 있으면 즉시 UI 업데이트
      _updateSelectedDogImmediately(result['selectedDogId']);

      // 그 후에 백그라운드에서 데이터 새로고침
      _refreshDataInBackground();
    } else if (mounted) {
      await _refreshData();
    }

    return result;
  }

  // Settings 페이지로의 최적화된 네비게이션 함수
  Future<void> _navigateToSettings() async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => SettingsPage(username: widget.username),
      ),
    );

    if (mounted && result is Map && result['selectedDogId'] != null) {
      // 선택된 강아지 ID가 있으면 즉시 UI 업데이트
      _updateSelectedDogImmediately(result['selectedDogId']);

      // 그 후에 백그라운드에서 데이터 새로고침
      _refreshDataInBackground();
    } else if (mounted) {
      await _refreshData();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: RefreshIndicator(
        onRefresh: _refreshData,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          child: SafeArea(
            top: true,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 상단 프로필 영역
                Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                  child: Row(
                    children: [
                      CircleAvatar(
                        radius: 24,
                        backgroundColor: const Color(0xFFE6E6E6),
                        child:
                            Icon(Icons.person, size: 32, color: Colors.black87),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          nickname.isNotEmpty ? nickname : '둘째누나',
                          style: const TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w600,
                            color: Colors.black,
                          ),
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.settings, size: 28),
                        onPressed: _navigateToSettings,
                      ),
                    ],
                  ),
                ),
                // 날씨+강아지 프로필 영역 (배경색 적용)
                Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                  child: Container(
                    decoration: BoxDecoration(
                      color: const Color(0xFFC7DBB5),
                      borderRadius: BorderRadius.circular(28),
                    ),
                    constraints: const BoxConstraints(minHeight: 380),
                    padding: const EdgeInsets.only(
                        top: 12, left: 8, right: 8, bottom: 12),
                    child: Column(
                      children: [
                        // 위치 텍스트
                        Padding(
                          padding: const EdgeInsets.only(
                              top: 0, bottom: 8, left: 16, right: 16),
                          child: Align(
                            alignment: Alignment.centerLeft,
                            child: Text(
                              '📍 $location',
                              style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w600,
                                color: Color(0xFF444444),
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ),
                        // 위치 및 온도 정보
                        Padding(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 0),
                          child: Container(
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(18),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withOpacity(0.03),
                                  blurRadius: 8,
                                  offset: const Offset(0, 2),
                                ),
                              ],
                            ),
                            padding: const EdgeInsets.symmetric(
                                vertical: 16, horizontal: 18),
                            child: Row(
                              children: [
                                // 온도 (왼쪽, flex:3)
                                Expanded(
                                  flex: 3,
                                  child: Align(
                                    alignment: Alignment.centerLeft,
                                    child: Padding(
                                      padding: const EdgeInsets.only(left: 12),
                                      child: Text(
                                        temperature != '--'
                                            ? '$temperature°C'
                                            : '15°C',
                                        style: const TextStyle(
                                          fontSize: 30,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 20),

                                // 미세먼지 (가운데, flex:2)
                                Expanded(
                                  flex: 2,
                                  child: Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    crossAxisAlignment:
                                        CrossAxisAlignment.center,
                                    children: [
                                      Icon(Icons.blur_on,
                                          size: 18, color: Colors.blueGrey),
                                      const SizedBox(height: 2),
                                      Text('미세먼지',
                                          style: TextStyle(
                                              fontSize: 13,
                                              color: Colors.black54)),
                                      Text(dustStatus,
                                          style: TextStyle(
                                              fontSize: 16,
                                              fontWeight: FontWeight.w600)),
                                    ],
                                  ),
                                ),
                                // 강수량 (오른쪽, flex:2)
                                Expanded(
                                  flex: 2,
                                  child: Padding(
                                    padding: const EdgeInsets.only(right: 20),
                                    child: Column(
                                      mainAxisAlignment:
                                          MainAxisAlignment.center,
                                      crossAxisAlignment:
                                          CrossAxisAlignment.center,
                                      children: [
                                        Icon(Icons.water_drop,
                                            size: 18, color: Colors.blueAccent),
                                        const SizedBox(height: 2),
                                        Text('강수량',
                                            style: TextStyle(
                                                fontSize: 13,
                                                color: Colors.black54)),
                                        Text('$precipitation mm',
                                            style: TextStyle(
                                                fontSize: 16,
                                                fontWeight: FontWeight.w600)),
                                      ],
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 18),
                        // 강아지 프로필
                        Center(
                          child: Column(
                            children: [
                              Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  IconButton(
                                    icon: const Icon(Icons.chevron_left,
                                        size: 32),
                                    onPressed: dogProfiles.length > 1 &&
                                            _currentPhotoIndex > 0
                                        ? () =>
                                            setState(() => _currentPhotoIndex--)
                                        : null,
                                  ),
                                  GestureDetector(
                                    onTap: () async {
                                      // 강아지 프로필이 없을 때 EditDogProfilePage로 이동
                                      if (dogProfiles.isEmpty) {
                                        final result = await Navigator.push(
                                          context,
                                          MaterialPageRoute(
                                            builder: (context) =>
                                                EditDogProfilePage(
                                              username: widget.username,
                                            ),
                                          ),
                                        );

                                        if (mounted) {
                                          if (result is Map &&
                                              result['selectedDogId'] != null) {
                                            _updateSelectedDogImmediately(
                                                result['selectedDogId']);
                                            _refreshDataInBackground();
                                          } else {
                                            await _refreshData();
                                          }
                                        }
                                        return;
                                      }

                                      // 강아지 프로필이 있을 때 기존 동작
                                      final result = await Navigator.push(
                                        context,
                                        MaterialPageRoute(
                                          builder: (context) => DogProfile(
                                            username: widget.username,
                                          ),
                                        ),
                                      );

                                      // 강아지 프로필에서 돌아온 후 최적화된 처리
                                      if (mounted &&
                                          result is Map &&
                                          result['selectedDogId'] != null) {
                                        _updateSelectedDogImmediately(
                                            result['selectedDogId']);
                                        _refreshDataInBackground();
                                      } else if (mounted) {
                                        await _refreshData();
                                      }
                                    },
                                    child: AnimatedSwitcher(
                                      duration:
                                          const Duration(milliseconds: 300),
                                      child: dogProfiles.isEmpty
                                          ? Container(
                                              key: const ValueKey('add_dog'),
                                              width: 200,
                                              height: 200,
                                              decoration: BoxDecoration(
                                                color: Colors.grey[200],
                                                shape: BoxShape.circle,
                                                border: Border.all(
                                                  color: Colors.grey[400]!,
                                                  width: 2,
                                                  style: BorderStyle.solid,
                                                ),
                                              ),
                                              child: Icon(
                                                Icons.add,
                                                size: 80,
                                                color: Colors.grey[600],
                                              ),
                                            )
                                          : CircleAvatar(
                                              key: ValueKey(_currentPhotoIndex),
                                              radius: 100,
                                              backgroundImage: dogProfiles[
                                                              _currentPhotoIndex]
                                                          ['image_url'] !=
                                                      ''
                                                  ? NetworkImage(dogProfiles[
                                                          _currentPhotoIndex]
                                                      ['image_url'])
                                                  : const AssetImage(
                                                          'assets/images/holdon.png')
                                                      as ImageProvider,
                                              backgroundColor: Colors.grey[200],
                                            ),
                                    ),
                                  ),
                                  IconButton(
                                    icon: const Icon(Icons.chevron_right,
                                        size: 32),
                                    onPressed: dogProfiles.length > 1 &&
                                            _currentPhotoIndex <
                                                dogProfiles.length - 1
                                        ? () =>
                                            setState(() => _currentPhotoIndex++)
                                        : null,
                                  ),
                                ],
                              ),
                              const SizedBox(height: 2),
                              AnimatedSwitcher(
                                duration: const Duration(milliseconds: 200),
                                child: Text(
                                  key: ValueKey(_currentPhotoIndex),
                                  dogProfiles.isNotEmpty
                                      ? dogProfiles[_currentPhotoIndex]
                                          ['dog_name']
                                      : '반려견을 추가해보세요',
                                  style: const TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.w500),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                // 산책하기 버튼
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: AnimatedSwitcher(
                      duration: const Duration(milliseconds: 200),
                      child: Text(
                        key: ValueKey(_currentPhotoIndex),
                        dogProfiles.isNotEmpty
                            ? '${dogProfiles[_currentPhotoIndex]['dog_name']}와 함께 산책해요'
                            : '반려견을 등록하고 산책해요',
                        style: const TextStyle(
                            fontSize: 16, fontWeight: FontWeight.bold),
                        textAlign: TextAlign.left,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    SizedBox(
                      width: 330,
                      height: 57,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFFE6F1E6),
                          foregroundColor: Colors.black,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                          elevation: 0,
                        ),
                        onPressed: dogProfiles.isEmpty
                            ? null // dogProfiles 없으면 버튼 비활성화
                            : () {
                                _navigateAndRefresh(WalkChoose(
                                  username: widget.username,
                                  dogId: dogProfiles[_currentPhotoIndex]['id'],
                                  dogName: dogProfiles[_currentPhotoIndex]
                                      ['dog_name'],
                                ));
                              },
                        child: const Text(
                          '산책하기',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                // 하단 3개 메뉴
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Align(
                        alignment: Alignment.centerLeft,
                        child: Text(
                          '그룹과 함께하는 우리 강아지 돌봄',
                          style: TextStyle(
                              fontSize: 16, fontWeight: FontWeight.bold),
                          textAlign: TextAlign.left,
                        ),
                      ),
                      const SizedBox(height: 16),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          SizedBox(
                            width: 300,
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                _buildMenuButton(Icons.calendar_month, '캘린더',
                                    () {
                                  _navigateAndRefresh(
                                      CalendarPage(username: widget.username));
                                }),
                                _buildMenuButton(Icons.article, '게시판', () {
                                  _navigateAndRefresh(
                                      BoardPage(username: widget.username));
                                }),
                                _buildMenuButton(Icons.bar_chart, '산책리스트', () {
                                  if (dogProfiles.isEmpty) return;
                                  _navigateAndRefresh(WorkList(
                                    username: widget.username,
                                    dogId: dogProfiles[_currentPhotoIndex]
                                        ['id'],
                                    dogName: dogProfiles[_currentPhotoIndex]
                                        ['dog_name'],
                                  ));
                                }),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildMenuButton(IconData icon, String label, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        children: [
          Container(
            width: 70,
            height: 70,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xFFE6E6E6)),
            ),
            child: Icon(icon, size: 36, color: Colors.black87),
          ),
          const SizedBox(height: 6),
          Text(label,
              style:
                  const TextStyle(fontSize: 14, fontWeight: FontWeight.w500)),
        ],
      ),
    );
  }
}
