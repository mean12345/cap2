import 'package:flutter/material.dart';
import 'package:flutter/services.dart'; // 추가
import '../colors.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:intl/intl.dart';
import 'package:table_calendar/table_calendar.dart';
import 'package:dangq/work/dog_list.dart';
import 'package:flutter_naver_map/flutter_naver_map.dart';
import 'dart:math'; // 추가: min, max 함수 사용을 위해
import 'package:dangq/work_list/work_route.dart'; // 추가

class WorkList extends StatefulWidget {
  final String username;
  final int dogId;
  final String dogName;

  const WorkList({
    required this.username,
    required this.dogId,
    required this.dogName,
    super.key,
  });
  @override
  State<WorkList> createState() => _WorkListState();
}

class _WorkListState extends State<WorkList> {
  List<Map<String, dynamic>> workItems = [];
  Map<DateTime, List<Map<String, dynamic>>> workoutsByDate = {};
  bool isLoading = true;
  // 강아지 프로필 관련 상태
  List<Map<String, dynamic>> dogProfiles = [];
  bool _isLoading = false;
  int _currentPhotoIndex = 0;
  // 캘린더 관련 상태
  DateTime _focusedDay = DateTime.now();
  DateTime _selectedDay = DateTime.now();
  CalendarFormat _calendarFormat = CalendarFormat.month;

  // 월별 총계 데이터
  String _monthlyTotalWalkTime = '00:00:00';
  String _monthlyTotalDistance = '0.00';
  String _monthlyTotalCount = '0';

  @override
  void initState() {
    super.initState();
    _selectedDogId = widget.dogId;
    _selectedDogName = widget.dogName;
    _fetchDogProfiles().then((_) {
      // 초기 프로필 인덱스 설정
      int index = dogProfiles.indexWhere((dog) => dog['id'] == widget.dogId);
      if (index != -1) {
        setState(() {
          _currentPhotoIndex = index;
          _selectedDogImageUrl = dogProfiles[index]['image_url'] ?? '';
        });
      }
    });
    fetchWorkoutData();
  }

  // 현재 선택된 강아지 정보
  late int _selectedDogId;
  late String _selectedDogName;
  String _selectedDogImageUrl = '';
  final String baseUrl = dotenv.get('BASE_URL');

  void _updateSelectedDog(int dogId, String dogName, String imageUrl) {
    setState(() {
      _selectedDogId = dogId;
      _selectedDogName = dogName;
      _selectedDogImageUrl = imageUrl;
    });
    // 선택된 강아지가 변경되면 해당 강아지의 운동 데이터를 다시 가져옴
    fetchWorkoutDataForDog(dogId);
  }

  Future<void> fetchWorkoutData() async {
    await fetchWorkoutDataForDog(widget.dogId);
  }

  Future<void> fetchWorkoutDataForDog(int dogId) async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/tracking/${widget.username}?dog_id=$dogId'),
      );

      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(response.body);
        print('서버 응답 데이터: $data');

        setState(() {
          workItems = data.map((item) {
            DateTime? startTime = item['start_time'] != null
                ? parseKoreanDateTime(item['start_time'])
                : null;
            DateTime? endTime = item['end_time'] != null
                ? parseKoreanDateTime(item['end_time'])
                : null;

            Duration duration = Duration();
            if (startTime != null && endTime != null) {
              duration = endTime.difference(startTime);
            } else {
              print('start 또는 end가 null임. 아이템: $item');
            }

            double distance =
                double.tryParse(item['distance']?.toString() ?? '0') ?? 0;
            double speedValue =
                double.tryParse(item['speed']?.toString() ?? '0') ?? 0;

            DateTime recordDate = startTime ?? DateTime.now();

            try {
              var pathData = [];
              if (item['path_data'] != null) {
                if (item['path_data'] is String) {
                  pathData = json.decode(item['path_data']);
                } else {
                  pathData = item['path_data'];
                }
              }

              return {
                'track_id': item['track_id']?.toString() ?? '',
                'username': item['username']?.toString() ?? '',
                'walkTime': _formatDuration(duration),
                'walkTimeDuration': duration,
                'distance': (distance / 1000).toStringAsFixed(2),
                'distanceValue': distance / 1000,
                'speed': speedValue.toStringAsFixed(2),
                'speedValue': speedValue,
                'created_at': recordDate.toIso8601String(),
                'date': recordDate,
                'path_data': pathData,
              };
            } catch (e) {
              print('데이터 처리 오류: $e');
              return {
                'track_id': item['track_id']?.toString() ?? '',
                'username': item['username']?.toString() ?? '',
                'walkTime': _formatDuration(duration),
                'walkTimeDuration': duration,
                'distance': (distance / 1000).toStringAsFixed(2),
                'distanceValue': distance / 1000,
                'speed': speedValue.toStringAsFixed(2),
                'speedValue': speedValue,
                'created_at': recordDate.toIso8601String(),
                'date': recordDate,
                'path_data': [],
              };
            }
          }).toList();

          workoutsByDate = {};
          for (var item in workItems) {
            DateTime date = item['date'];
            DateTime dateOnly = DateTime(date.year, date.month, date.day);
            workoutsByDate[dateOnly] ??= [];
            workoutsByDate[dateOnly]!.add(item);
          }

          isLoading = false;
          _calculateMonthlyTotals();
        });
      } else {
        print('서버 응답 오류: ${response.statusCode}');
        setState(() {
          isLoading = false;
        });
      }
    } catch (e) {
      print('Error fetching data: $e');
      setState(() {
        isLoading = false;
      });
    }
  }

  DateTime? parseKoreanDateTime(String dateStr) {
    try {
      final format = DateFormat('yyyy. M. d. a h:mm:ss', 'ko');
      return format.parse(dateStr);
    } catch (e) {
      return null;
    }
  }

  void _calculateMonthlyTotals() {
    try {
      final int currentMonth = _focusedDay.month;
      final int currentYear = _focusedDay.year;

      Duration totalDuration = Duration();
      double totalDistance = 0.0;
      int walkCount = 0;

      for (var item in workItems) {
        DateTime itemDate = item['date'];
        if (itemDate.month == currentMonth && itemDate.year == currentYear) {
          totalDuration += item['walkTimeDuration'] as Duration;
          totalDistance += item['distanceValue'] as double;
          walkCount++;
        }
      }

      setState(() {
        _monthlyTotalWalkTime = _formatDuration(totalDuration);
        _monthlyTotalDistance = totalDistance.toStringAsFixed(2);
        _monthlyTotalCount = walkCount.toString();
      });
    } catch (e) {
      print('월별 총계 계산 오류: $e');
    }
  }

  String _formatDuration(Duration duration) {
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    String hours = twoDigits(duration.inHours);
    String minutes = twoDigits(duration.inMinutes.remainder(60));
    String seconds = twoDigits(duration.inSeconds.remainder(60));
    return "$hours:$minutes:$seconds";
  }

  // Delete workout record
  Future<void> _deleteWorkout(String trackId) async {
    try {
      final response = await http.delete(
        Uri.parse('$baseUrl/tracking/$trackId'),
      );
      if (response.statusCode == 200) {
        setState(() {
          workItems.removeWhere((item) => item['track_id'] == trackId);
          // 다시 그룹화
          workoutsByDate = {};
          for (var item in workItems) {
            DateTime date = item['date'];
            DateTime dateOnly = DateTime(date.year, date.month, date.day);
            if (workoutsByDate[dateOnly] == null) {
              workoutsByDate[dateOnly] = [];
            }
            workoutsByDate[dateOnly]!.add(item);
          }
          _calculateMonthlyTotals();
        });
      }
    } catch (e) {
      print('Error deleting workout: $e');
    }
  }

  Future<void> _fetchDogProfiles() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final url = '$baseUrl/dogs/get_dogs?username=${widget.username}';
      final response = await http.get(Uri.parse(url));

      if (response.statusCode == 200) {
        final List<dynamic> jsonResponse = json.decode(response.body);
        setState(() {
          dogProfiles = jsonResponse
              .map<Map<String, dynamic>>((dog) => {
                    'dog_name': dog['name'],
                    'image_url': dog['imageUrl'],
                    'id': dog['id'],
                  })
              .toList();

          // 초기 선택된 강아지의 인덱스 찾기
          int index =
              dogProfiles.indexWhere((dog) => dog['id'] == widget.dogId);
          if (index != -1) {
            _currentPhotoIndex = index;
            _selectedDogImageUrl = dogProfiles[index]['image_url'] ?? '';
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

  // 강아지 선택 다이얼로그
  void _showDogSelectionDialog() {
    if (dogProfiles.isEmpty) return;

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return Dialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(5),
          ),
          child: Container(
            padding: EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(5),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  '반려견 선택',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                SizedBox(height: 20),
                Container(
                  constraints: BoxConstraints(
                    maxHeight: MediaQuery.of(context).size.height * 0.4,
                  ),
                  padding: EdgeInsets.symmetric(vertical: 10),
                  child: GridView.builder(
                    shrinkWrap: true,
                    physics: BouncingScrollPhysics(),
                    gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 3,
                      crossAxisSpacing: 8,
                      mainAxisSpacing: 16,
                      childAspectRatio: 0.8, // 추가: 아이템의 세로 비율 조정
                    ),
                    itemCount: dogProfiles.length,
                    itemBuilder: (context, index) {
                      final dog = dogProfiles[index];
                      return GestureDetector(
                        onTap: () {
                          _updateSelectedDog(
                            dog['id'],
                            dog['dog_name'] ?? '이름 없음',
                            dog['image_url'] ?? '',
                          );
                          Navigator.pop(context);
                        },
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            CircleAvatar(
                              radius: 30,
                              backgroundImage: dog['image_url'] != null &&
                                      dog['image_url'].isNotEmpty
                                  ? NetworkImage(dog['image_url'])
                                  : AssetImage('assets/images/default_dog.png')
                                      as ImageProvider,
                              backgroundColor: Colors.grey[300],
                            ),
                            SizedBox(height: 8),
                            Text(
                              dog['dog_name'] ?? '이름 없음',
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w500,
                              ),
                              textAlign: TextAlign.center,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    // 상태바 스타일 설정
    SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
      statusBarColor: Color(0xFFF4F4F4), // AppColors.background와 동일한 색상
      statusBarIconBrightness: Brightness.dark,
    ));

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        scrolledUnderElevation: 0,
        toolbarHeight: MediaQuery.of(context).size.height * 0.07,
        title: const Text(
          '일정 목록',
          style: TextStyle(
            color: Colors.black,
            fontSize: 18,
            fontWeight: FontWeight.w500,
          ),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black),
          onPressed: () => Navigator.of(context).pop(),
        ),
        backgroundColor: Colors.white,
        elevation: 0,
      ),
      body: isLoading
          ? Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              child: Column(
                children: [
                  _buildDogProfileSection(),
                  _buildCalendar(),
                  _buildMonthlyTotalSection(),
                  _buildSelectedDayWorkouts(),
                ],
              ),
            ),
    );
  }

  // 반려견 프로필 섹션
  Widget _buildDogProfileSection() {
    return Container(
      margin: EdgeInsets.fromLTRB(8, 8, 8, 0),
      padding: EdgeInsets.symmetric(vertical: 16, horizontal: 20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.2),
            spreadRadius: 1,
            blurRadius: 3,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: GestureDetector(
        onTap: _showDogSelectionDialog,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 60,
              height: 60,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: AppColors.green, width: 2),
              ),
              child: CircleAvatar(
                radius: 28,
                backgroundImage: _selectedDogImageUrl.isNotEmpty
                    ? NetworkImage(_selectedDogImageUrl)
                    : AssetImage('assets/images/default_dog.png')
                        as ImageProvider,
                backgroundColor: Colors.grey[300],
              ),
            ),
            SizedBox(width: 16),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _selectedDogName,
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Colors.black87,
                  ),
                ),
                SizedBox(height: 4),
                Text(
                  '산책 기록',
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey[600],
                  ),
                ),
              ],
            ),
            Spacer(),
            if (dogProfiles.length > 1)
              Icon(
                Icons.keyboard_arrow_down,
                color: Colors.grey[600],
                size: 24,
              ),
          ],
        ),
      ),
    );
  }

  // 월별 총계 섹션
  Widget _buildMonthlyTotalSection() {
    final String monthName = DateFormat('yyyy년 M월').format(_focusedDay);
    return Container(
      margin: EdgeInsets.fromLTRB(8, 8, 8, 8),
      padding: EdgeInsets.symmetric(vertical: 12, horizontal: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.2),
            spreadRadius: 1,
            blurRadius: 3,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: EdgeInsets.only(bottom: 12),
            child: Text(
              '$monthName 산책 기록',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          Row(
            children: [
              _buildMonthlySummaryCard(
                '총 소요 시간',
                _monthlyTotalWalkTime,
                Icons.access_time,
              ),
              SizedBox(width: 8),
              _buildMonthlySummaryCard(
                '총 이동 거리',
                '$_monthlyTotalDistance km',
                Icons.straighten,
              ),
              SizedBox(width: 8),
              _buildMonthlySummaryCard(
                '산책 횟수',
                _monthlyTotalCount,
                Icons.directions_walk,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMonthlySummaryCard(String title, String value, IconData icon) {
    return Expanded(
      child: Container(
        padding: EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: AppColors.green.withOpacity(0.05),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: AppColors.green.withOpacity(0.3), width: 1),
        ),
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(icon, size: 16, color: AppColors.green),
                SizedBox(width: 4),
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 11,
                    color: Colors.grey[600],
                  ),
                ),
              ],
            ),
            SizedBox(height: 8),
            Text(
              title == '산책 횟수' ? '${value}회' : value,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCalendar() {
    return Container(
      margin: EdgeInsets.fromLTRB(8, 0, 8, 0),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.2),
            spreadRadius: 1,
            blurRadius: 3,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: TableCalendar(
        locale: 'ko_KR',
        firstDay: DateTime.utc(2020, 1, 1),
        lastDay: DateTime.utc(2030, 12, 31),
        focusedDay: _focusedDay,
        calendarFormat: _calendarFormat,
        eventLoader: (day) {
          final dateOnly = DateTime(day.year, day.month, day.day);
          return workoutsByDate[dateOnly] ?? [];
        },
        selectedDayPredicate: (day) {
          return isSameDay(_selectedDay, day);
        },
        onDaySelected: (selectedDay, focusedDay) {
          if (!isSameDay(_selectedDay, selectedDay)) {
            setState(() {
              _selectedDay = selectedDay;
              _focusedDay = focusedDay;
            });
          }
        },
        onFormatChanged: (format) {
          if (_calendarFormat != format) {
            setState(() {
              _calendarFormat = format;
            });
          }
        },
        onPageChanged: (focusedDay) {
          setState(() {
            _focusedDay = focusedDay;
            _calculateMonthlyTotals();
          });
        },
        calendarStyle: CalendarStyle(
          markerDecoration: BoxDecoration(
            color: AppColors.green,
            shape: BoxShape.circle,
          ),
          todayDecoration: BoxDecoration(
            color: AppColors.green.withOpacity(0.1),
            shape: BoxShape.circle,
          ),
          todayTextStyle: TextStyle(
            color: Colors.black87,
            fontWeight: FontWeight.bold,
          ),
          selectedDecoration: BoxDecoration(
            border: Border.all(color: AppColors.green, width: 2),
            shape: BoxShape.circle,
          ),
          selectedTextStyle: TextStyle(
            color: Colors.black87,
            fontWeight: FontWeight.bold,
          ),
        ),
        headerStyle: HeaderStyle(
          formatButtonVisible: false,
          titleCentered: true,
          formatButtonShowsNext: false,
        ),
      ),
    );
  }

  Widget _buildSelectedDayWorkouts() {
    final dateOnly =
        DateTime(_selectedDay.year, _selectedDay.month, _selectedDay.day);
    final selectedWorkouts = workoutsByDate[dateOnly] ?? [];

    if (selectedWorkouts.isEmpty) {
      return Padding(
        padding: EdgeInsets.all(16),
        child: Center(
          child: Text(
            '이 날의 산책 기록이 없습니다.',
            style: TextStyle(color: Colors.grey[600], fontSize: 16),
          ),
        ),
      );
    }

    return Column(
      children: selectedWorkouts.map((workout) {
        return Padding(
          padding: EdgeInsets.fromLTRB(16, 0, 16, 16),
          child: WorkListItem(
            walkTime: workout['walkTime'],
            distance: workout['distance'],
            speed: workout['speed'],
            username: workout['username'],
            createdAt: _formatDisplayDate(workout['created_at']),
            pathData: workout['path_data'],
            dogName: _selectedDogName,
            dogImageUrl: _selectedDogImageUrl,
            onDelete: () => _showDeleteConfirmation(workout),
          ),
        );
      }).toList(),
    );
  }

  String _formatDisplayDate(String dateString) {
    try {
      DateTime dateTime = DateTime.parse(dateString);
      return DateFormat('yyyy-MM-dd HH:mm').format(dateTime);
    } catch (e) {
      return dateString;
    }
  }

  void _showDeleteConfirmation(Map<String, dynamic> item) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return Dialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(5),
          ),
          child: Container(
            padding: EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(5),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  '삭제 확인',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                SizedBox(height: 25),
                Text('이 산책 기록을 삭제하시겠습니까?'),
                SizedBox(height: 20),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    TextButton(
                      child: Text(
                        '취소',
                        style: TextStyle(color: Colors.grey),
                      ),
                      onPressed: () => Navigator.pop(context),
                    ),
                    SizedBox(width: 30),
                    TextButton(
                      child: Text(
                        '삭제',
                        style: TextStyle(color: AppColors.green),
                      ),
                      onPressed: () async {
                        await _deleteWorkout(item['track_id']);
                        Navigator.pop(context);
                      },
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class WorkListItem extends StatelessWidget {
  final String walkTime;
  final String distance;
  final String speed;
  final String username;
  final String createdAt;
  final List<dynamic> pathData;
  final String dogName;
  final String dogImageUrl;
  final VoidCallback? onDelete;

  const WorkListItem({
    required this.walkTime,
    required this.distance,
    required this.speed,
    required this.username,
    required this.createdAt,
    required this.pathData,
    required this.dogName,
    required this.dogImageUrl,
    this.onDelete,
    Key? key,
  }) : super(key: key);

  void _showPathOnMap(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => WorkRoute(
          pathData: pathData,
          username: username,
          createdAt: createdAt,
          dogName: dogName,
          dogImageUrl: dogImageUrl,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => _showPathOnMap(context),
      child: Container(
        height: 180,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(8),
          boxShadow: [
            BoxShadow(
              color: Colors.grey.withOpacity(0.2),
              spreadRadius: 1,
              blurRadius: 3,
              offset: Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          children: [
            // 헤더
            Padding(
              padding: EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Text(
                        username,
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      SizedBox(width: 10),
                      Text(
                        createdAt,
                        style: TextStyle(
                          fontSize: 13,
                          color: Colors.grey,
                        ),
                      ),
                    ],
                  ),
                  GestureDetector(
                    onTap: onDelete,
                    child: Icon(
                      Icons.delete,
                      color: Colors.red,
                      size: 22,
                    ),
                  ),
                ],
              ),
            ),
            Divider(),
            // 내용
            Padding(
              padding: EdgeInsets.symmetric(vertical: 12),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  _buildInfoColumn("소요 시간", walkTime),
                  _buildDivider(),
                  _buildInfoColumn("이동 거리", "$distance km"),
                  _buildDivider(),
                  _buildInfoColumn("속력", "$speed km/h"),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoColumn(String label, String value) {
    return Expanded(
      child: Column(
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey[600],
            ),
          ),
          SizedBox(height: 8),
          Text(
            value,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDivider() {
    return Container(
      height: 40,
      width: 1,
      color: Colors.grey.withOpacity(0.2),
    );
  }
}
