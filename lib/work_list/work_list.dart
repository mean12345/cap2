import 'package:flutter/material.dart';
import '../colors.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:intl/intl.dart';
import 'package:table_calendar/table_calendar.dart';
import 'package:dangq/work/dog_list.dart';

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
  String _monthlyTotalSteps = '0';

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

  void _updateSelectedDog(int dogId, String dogName, String imageUrl) {
    setState(() {
      _selectedDogId = dogId;
      _selectedDogName = dogName;
      _selectedDogImageUrl = imageUrl;
    });
  }

  final String baseUrl = dotenv.get('BASE_URL');

  Future<void> fetchWorkoutData() async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/tracking/${widget.username}'),
      );

      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(response.body);
        setState(() {
          workItems = data
              .map((item) {
                try {
                  DateTime? startTime =
                      _parseKoreanDateTime(item['start_time']);
                  DateTime? endTime = _parseKoreanDateTime(item['end_time']);

                  Duration duration = Duration();

                  if (startTime != null && endTime != null) {
                    duration = endTime.difference(startTime);
                  } else {
                    print('start 또는 end가 null임. 아이템: $item');
                  }

                  int stepCount =
                      int.tryParse(item['step_count']?.toString() ?? '0') ?? 0;
                  double distance =
                      double.tryParse(item['distance']?.toString() ?? '0') ?? 0;

                  String createdAt =
                      item['created_at']?.toString() ??
                          DateTime.now().toString().split(' ')[0];

                  return {
                    'track_id': item['track_id']?.toString() ?? '',
                    'username': item['username']?.toString() ?? '',
                    'walkTime': _formatDuration(duration),
                    'walkTimeDuration': duration,
                    'distance': (distance / 1000).toStringAsFixed(2),
                    'distanceValue': distance / 1000,
                    'steps': stepCount.toString(),
                    'stepsValue': stepCount,
                    'created_at': createdAt,
                    'date': _parseDate(createdAt),
                  };
                } catch (e) {
                  print('Data processing error: $e');
                  return null;
                }
              })
              .where((item) => item != null)
              .cast<Map<String, dynamic>>()
              .toList();

          // 날짜별로 운동 데이터 그룹화
          workoutsByDate = {};
          for (var item in workItems) {
            DateTime date = item['date'];
            DateTime dateOnly = DateTime(date.year, date.month, date.day);
            if (workoutsByDate[dateOnly] == null) {
              workoutsByDate[dateOnly] = [];
            }
            workoutsByDate[dateOnly]!.add(item);
          }

          // 현재 보고 있는 월의 총계 데이터 계산
          _calculateMonthlyTotals();
        });
      } else if (response.statusCode == 404) {
        // 데이터가 없는 경우
        setState(() {
          workItems = [];
          workoutsByDate = {};
          _calculateMonthlyTotals();
        });
      } else {
        print('Error response: ${response.statusCode}');
        throw Exception('Failed to load workout data');
      }
    } catch (e) {
      print('Error fetching data: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('산책 기록을 불러오는데 실패했습니다.')),
      );
    } finally {
      setState(() {
        isLoading = false;
      });
    }
  }

  // 월별 총계 계산 함수
  void _calculateMonthlyTotals() {
    try {
      final int currentMonth = _focusedDay.month;
      final int currentYear = _focusedDay.year;

      Duration totalDuration = Duration();
      double totalDistance = 0.0;
      int totalSteps = 0;

      for (var item in workItems) {
        DateTime itemDate = item['date'];
        if (itemDate.month == currentMonth && itemDate.year == currentYear) {
          totalDuration += item['walkTimeDuration'] as Duration;
          totalDistance += item['distanceValue'] as double;
          totalSteps += item['stepsValue'] as int;
        }
      }

      setState(() {
        _monthlyTotalWalkTime = _formatDuration(totalDuration);
        _monthlyTotalDistance = totalDistance.toStringAsFixed(2);
        _monthlyTotalSteps = totalSteps.toString();
      });
    } catch (e) {
      print('월별 총계 계산 오류: $e');
    }
  }

  DateTime _parseDate(String dateString) {
    try {
      return DateTime.parse(dateString);
    } catch (e) {
      print('날짜 파싱 실패: $e');
      return DateTime.now();
    }
  }

  DateTime? _parseKoreanDateTime(String? dateString) {
    if (dateString == null || dateString.isEmpty) {
      return null;
    }
    try {
      return DateFormat('yyyy. M. d. a h:mm:ss', 'ko_KR').parse(dateString);
    } catch (e) {
      print('시간 파싱 실패: $e');
      return null;
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        scrolledUnderElevation: 0,
        toolbarHeight: MediaQuery.of(context).size.height * 0.05,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black, size: 35),
          onPressed: () {
            Navigator.pop(context, {
              'dogId': _selectedDogId,
              'dogName': _selectedDogName,
              'imageUrl': _selectedDogImageUrl,
            });
          },
        ),
        title: Text(
          '산책 기록',
          style: TextStyle(color: Colors.black87, fontWeight: FontWeight.w300),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: isLoading
          ? Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              child: Column(
                children: [
                  _buildCalendar(),
                  _buildMonthlyTotalSection(),
                  Container(
                    // 마지막 섹션의 높이를 명시적으로 설정
                    constraints: BoxConstraints(
                      minHeight: MediaQuery.of(context).size.height * 0.4,
                    ),
                    child: _buildSelectedDayWorkouts(),
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
      margin: EdgeInsets.fromLTRB(8, 0, 8, 8),
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
                '총 속력',
                '$_monthlyTotalSteps km/h',
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
              value,
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
      margin: EdgeInsets.all(8.0),
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
        children: [
          SizedBox(height: 16),
          if (_isLoading)
            CircularProgressIndicator()
          else if (dogProfiles.isEmpty)
            Text('등록된 반려견이 없습니다.')
          else
            GestureDetector(
              onTap: () async {
                final result = await Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => DogListPage(
                      username: widget.username,
                      onDogSelected: (int id, String name, String imageUrl) {
                        _updateSelectedDog(id, name, imageUrl);
                      },
                    ),
                  ),
                );

                // DogListPage에서 돌아온 후 프로필 새로고침
                if (result != null) {
                  await _fetchDogProfiles();
                }
              },
              child: Container(
                width: 100,
                height: 100,
                margin: EdgeInsets.all(8),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  image: _selectedDogImageUrl.isNotEmpty
                      ? DecorationImage(
                          image: NetworkImage(_selectedDogImageUrl),
                          fit: BoxFit.cover,
                        )
                      : null,
                  color: _selectedDogImageUrl.isEmpty ? Colors.grey[300] : null,
                ),
                child: _selectedDogImageUrl.isEmpty
                    ? Icon(Icons.pets, size: 50, color: Colors.grey)
                    : null,
              ),
            ),
          if (dogProfiles.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Text(
                _selectedDogName,
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
              ),
            ),
          SizedBox(height: 8),
          TableCalendar(
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
              selectedDecoration: BoxDecoration(
                border: Border.all(color: AppColors.green, width: 2),
                shape: BoxShape.circle,
              ),
              selectedTextStyle: TextStyle(
                color: Colors.black87,
                fontWeight: FontWeight.bold,
              ),
              todayTextStyle: TextStyle(
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
        ],
      ),
    );
  }

  // _buildSelectedDayWorkouts 메서드를 수정
  Widget _buildSelectedDayWorkouts() {
    final dateOnly =
        DateTime(_selectedDay.year, _selectedDay.month, _selectedDay.day);
    final selectedWorkouts = workoutsByDate[dateOnly] ?? [];

    if (selectedWorkouts.isEmpty) {
      return Center(
        child: Padding(
          padding: EdgeInsets.all(20),
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
          padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: WorkListItem(
            walkTime: workout['walkTime'],
            distance: workout['distance'],
            steps: workout['steps'],
            username: workout['username'],
            createdAt: workout['created_at'],
            onDelete: () => _showDeleteConfirmation(workout),
          ),
        );
      }).toList(),
    );
  }

  String _formatDisplayDate(String dateString) {
    try {
      DateTime dateTime = DateTime.parse(dateString);
      return DateFormat('yyyy년 MM월 dd일 HH:mm').format(dateTime);
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
  final String steps;
  final String username;
  final String createdAt;
  final VoidCallback? onDelete;

  const WorkListItem({
    required this.walkTime,
    required this.distance,
    required this.steps,
    required this.username,
    required this.createdAt,
    this.onDelete,
    Key? key,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Container(
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
                Expanded(
                  child: Row(
                    children: [
                      Text(
                        username,
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      SizedBox(width: 10),
                      Flexible(
                        child: Text(
                          createdAt,
                          style: TextStyle(
                            fontSize: 13,
                            color: Colors.grey,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
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
                _buildInfoColumn("속력", "$steps km/h"),
              ],
            ),
          ),
        ],
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

class work extends StatefulWidget {
  const work({super.key});

  @override
  State<work> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<work> {
  CalendarFormat _calendarFormat = CalendarFormat.month;
  DateTime _focusedDay = DateTime.now();
  DateTime? _selectedDay;
  final Set<DateTime> _walkDays = {};

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        centerTitle: true,
        title: const CircleAvatar(
          radius: 25,
          backgroundImage: NetworkImage('https://i.imgur.com/qgaYJWX.png'),
          backgroundColor: Colors.grey,
        ),
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            TableCalendar(
              firstDay: DateTime.utc(2024, 1, 1),
              lastDay: DateTime.utc(2025, 12, 31),
              focusedDay: _focusedDay,
              calendarFormat: _calendarFormat,
              selectedDayPredicate: (day) {
                return isSameDay(_selectedDay, day);
              },
              onDaySelected: (selectedDay, focusedDay) {
                setState(() {
                  _selectedDay = selectedDay;
                  _focusedDay = focusedDay;
                });
              },
              onFormatChanged: (format) {
                setState(() {
                  _calendarFormat = format;
                });
              },
              eventLoader: (day) {
                return _walkDays.contains(day) ? ['산책'] : [];
              },
              calendarStyle: const CalendarStyle(
                markerDecoration: BoxDecoration(
                  color: Colors.green,
                  shape: BoxShape.circle,
                ),
              ),
            ),
            const SizedBox(height: 20),
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _buildStatCard('이동거리', '-km'),
                  _buildStatCard('평균 속력', '-km/h'),
                  _buildStatCard('소요시간', '-시간'),
                ],
              ),
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          setState(() {
            _walkDays.add(_focusedDay);
          });
        },
        child: const Icon(Icons.add),
      ),
    );
  }

  Widget _buildStatCard(String title, String value) {
    return Card(
      elevation: 4,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            Text(
              title,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              value,
              style: const TextStyle(
                fontSize: 18,
                color: Colors.green,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

