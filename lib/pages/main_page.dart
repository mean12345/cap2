import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await dotenv.load(fileName: 'assets/.env'); // .env 로드
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: '반려견 돌봄 앱',
      debugShowCheckedModeBanner: false,
      home: const MainPage(username: '둘째누나'),
    );
  }
}

class MainPage extends StatefulWidget {
  final String username;
  const MainPage({super.key, required this.username});

  @override
  State<MainPage> createState() => _MainPageState();
}

class _MainPageState extends State<MainPage> {
  String temperature = '--'; // 기온
  String dustStatus = '정보없음'; // 미세먼지 상태(임시)
  String uvStatus = '정보없음'; // 자외선 상태(임시)

  @override
  void initState() {
    super.initState();
    fetchWeather();
  }

  // 클래스 맨 위쪽 상태 변수 추가
  String location = '위치 불러오는 중...';

  Future<void> fetchWeather() async {
    try {
      final apiKey = dotenv.env['OPENWEATHER_API_KEY'];
      if (apiKey == null) throw Exception('API 키 누락');

      // 위치 권한 체크 및 요청
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.deniedForever) {
        throw Exception('위치 권한 거부됨');
      }

      // 현재 위치 가져오기
      Position pos = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );

      // --- 위치 이름(주소) 가져오기 (역지오코딩) ---
      try {
        List<Placemark> placemarks = await placemarkFromCoordinates(
          pos.latitude,
          pos.longitude,
        );
        if (placemarks.isNotEmpty) {
          final place = placemarks[0];
          // 예: "대구 달서구 신당동"
          location =
              '${place.administrativeArea} ${place.subAdministrativeArea} ${place.locality}';
        } else {
          location = '알 수 없는 위치';
        }
      } catch (e) {
        location = '위치 정보 없음';
        print('역지오코딩 실패: $e');
      }

      // OpenWeatherMap API 호출 (기본 날씨 정보)
      final url =
          'https://api.openweathermap.org/data/2.5/weather?lat=${pos.latitude}&lon=${pos.longitude}&appid=$apiKey&units=metric&lang=kr';

      final response = await http.get(Uri.parse(url));
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final temp = data['main']['temp'];

        // 미세먼지 API 호출
        final airUrl =
            'http://api.openweathermap.org/data/2.5/air_pollution?lat=${pos.latitude}&lon=${pos.longitude}&appid=$apiKey';
        final airResponse = await http.get(Uri.parse(airUrl));
        String dust = '정보없음';
        if (airResponse.statusCode == 200) {
          final airData = json.decode(airResponse.body);
          final pm25 = airData['list'][0]['components']['pm2_5'];

          if (pm25 <= 15) {
            dust = '좋음';
          } else if (pm25 <= 35) {
            dust = '보통';
          } else if (pm25 <= 75) {
            dust = '나쁨';
          } else {
            dust = '매우나쁨';
          }
        }

        // 자외선 API 호출
        final uvUrl =
            'http://api.openweathermap.org/data/2.5/uvi?lat=${pos.latitude}&lon=${pos.longitude}&appid=$apiKey';
        final uvResponse = await http.get(Uri.parse(uvUrl));
        String uv = '정보없음';
        if (uvResponse.statusCode == 200) {
          final uvData = json.decode(uvResponse.body);
          final uvIndex = uvData['value'];

          if (uvIndex <= 2) {
            uv = '좋음';
          } else if (uvIndex <= 5) {
            uv = '보통';
          } else if (uvIndex <= 7) {
            uv = '높음';
          } else {
            uv = '매우높음';
          }
        }

        // 상태값 업데이트
        setState(() {
          temperature = temp.toStringAsFixed(1);
          dustStatus = dust;
          uvStatus = uv;
          // 위치 정보도 같이 업데이트
          location = location;
        });
      } else {
        throw Exception('날씨 정보를 가져오지 못했습니다');
      }
    } catch (e) {
      setState(() {
        temperature = '--';
        dustStatus = '정보없음';
        uvStatus = '정보없음';
        location = '위치 정보 없음';
      });
      print('날씨 불러오기 실패: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Stack(
          children: [
            // 배경 (하늘 + 언덕)
            Positioned.fill(
              child: Column(
                children: [
                  Container(height: 200, color: const Color(0xffc4dbe1)),
                  Expanded(
                    child: Container(
                      decoration: const BoxDecoration(
                        color: Color(0xffbae2ad),
                        borderRadius: BorderRadius.vertical(
                          top: Radius.circular(150),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // 콘텐츠
            Positioned.fill(
              child: Column(
                children: [
                  // 프로필 바
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 12,
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            CircleAvatar(
                              radius: 20,
                              backgroundColor: Colors.orange,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              widget.username,
                              style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                        IconButton(
                          icon: const Icon(Icons.settings, size: 28),
                          onPressed: () {},
                        ),
                      ],
                    ),
                  ),
                  // 위치 정보 부분 (const 빼고 변수로 변경)
                  Container(
                    color: const Color(0xffc4dbe1),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 12,
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.location_on, color: Colors.red),
                        const SizedBox(width: 4),
                        Text(
                          location, // 변수 넣기
                          style: const TextStyle(fontSize: 16),
                        ),
                      ],
                    ),
                  ),

                  // 날씨 정보 (기존과 동일)
                  Container(
                    color: const Color(0xffc4dbe1),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 8,
                    ),
                    child: Row(
                      children: [
                        Text(
                          '$temperature°C',
                          style: const TextStyle(
                            fontSize: 40,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const Spacer(),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('미세먼지', style: TextStyle(fontSize: 14)),
                            Text(
                              dustStatus,
                              style: TextStyle(
                                fontSize: 14,
                                color:
                                    dustStatus == '좋음'
                                        ? Colors.blue
                                        : Colors.red,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(width: 24),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('자외선', style: TextStyle(fontSize: 14)),
                            Text(
                              uvStatus,
                              style: TextStyle(
                                fontSize: 14,
                                color:
                                    uvStatus == '좋음' ? Colors.blue : Colors.red,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  // 반려견 프로필 설정 영역
                  Container(
                    width: double.infinity,
                    color: const Color(0xffc4dbe1),
                    padding: const EdgeInsets.symmetric(vertical: 24),
                    child: Center(
                      child: Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(16),
                        margin: const EdgeInsets.symmetric(horizontal: 0),
                        decoration: BoxDecoration(
                          color: Color.fromRGBO(255, 255, 255, 0.3),
                        ),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: const [
                                Icon(Icons.chevron_left, size: 24),
                                SizedBox(width: 16),
                                CircleAvatar(
                                  radius: 36,
                                  backgroundColor: Colors.white,
                                  child: Icon(
                                    Icons.add,
                                    size: 36,
                                    color: Colors.grey,
                                  ),
                                ),
                                SizedBox(width: 16),
                                Icon(Icons.chevron_right, size: 24),
                              ],
                            ),
                            const SizedBox(height: 8),
                            const Text(
                              '반려견 프로필을 설정해보세요',
                              style: TextStyle(fontSize: 14),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),

                  // 기능 아이콘 3개 (이미지로 교체됨)
                  Container(
                    color: const Color(0xffc4dbe1),
                    padding: const EdgeInsets.only(top: 8, bottom: 24),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        _buildFeatureImageIcon('calendar.png'),
                        _buildFeatureImageIcon('post.png'),
                        _buildFeatureImageIcon('list.png'),
                      ],
                    ),
                  ),
                  // 하단 안내 텍스트 + 산책하기 버튼
                  const SizedBox(height: 8),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Image.asset(
                          'assets/images/yellow_flower.png', // 이미지 경로
                          width: 24,
                          height: 24,
                        ),
                        const SizedBox(width: 4),
                        const Text(
                          '반려견의 프로필을 설정해주세요',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const SizedBox(width: 4),
                        Image.asset(
                          'assets/images/yellow_flower.png',
                          width: 24,
                          height: 24,
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 12),
                  ElevatedButton(
                    onPressed: () {},
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xffebfae8),
                      foregroundColor: Colors.black,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 60,
                        vertical: 14,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(18),
                      ),
                    ),
                    child: const Text('산책하기'),
                  ),
                  const SizedBox(height: 24),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFeatureImageIcon(String assetName) {
    // post 아이콘은 오른쪽으로 밀기 위해 padding 조정
    // list 아이콘은 패딩을 작게 해서 이미지가 더 크게 보이도록 조정
    EdgeInsets padding;
    double imageSize;

    if (assetName == 'post.png') {
      padding = const EdgeInsets.fromLTRB(8, 8, 2, 8); // 오른쪽 padding 줄임
      imageSize = 40;
    } else if (assetName == 'list.png') {
      padding = const EdgeInsets.all(4); // 패딩 작게
      imageSize = 60; // 이미지 크기 키움
    } else {
      padding = const EdgeInsets.all(8);
      imageSize = 40;
    }

    return Container(
      width: 64,
      height: 64,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(color: Colors.black12, blurRadius: 4, offset: Offset(0, 2)),
        ],
      ),
      child: Padding(
        padding: padding,
        child: Image.asset(
          'assets/images/$assetName',
          fit: BoxFit.contain,
          width: imageSize,
          height: imageSize,
        ),
      ),
    );
  }
}
