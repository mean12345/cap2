import 'package:flutter/material.dart';
import '../colors.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:intl/intl.dart';
import 'package:table_calendar/table_calendar.dart';

class WorkList extends StatefulWidget {
  final String username;
  final int dogId;

  const WorkList({required this.username, required this.dogId, super.key});

  @override
  State<WorkList> createState() => _WorkListState();
}

class _WorkListState extends State<WorkList> {
  List<Map<String, dynamic>> workItems = [];
  Map<DateTime, List<Map<String, dynamic>>> workoutsByDate = {};
  bool isLoading = true;

  // 캘린더 관련 상태
  DateTime _focusedDay = DateTime.now();
  DateTime _selectedDay = DateTime.now();
  CalendarFormat _calendarFormat = CalendarFormat.month;

  // 월별 총계 데이터
  String _monthlyTotalWalkTime = '00:00:00';
  String _monthlyTotalDistance = '0.00';
  String _monthlyTotalSpeed = '0';

  @override
  void initState() {
    super.initState();
    fetchWorkoutData();
  }

  final String baseUrl = dotenv.get('BASE_URL');

  Future<void> fetchWorkoutData() async {
    try {
      final response = await http.get(
        Uri.parse(
            '$baseUrl/tracking/${widget.username}?dog_id=${widget.dogId}'),
      );

      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(response.body);
        if (data.isNotEmpty) {}

        DateTime? parseKoreanDateTime(String dateStr) {
          try {
            final format = DateFormat('yyyy. M. d. a h:mm:ss', 'ko');
            return format.parse(dateStr);
          } catch (e) {
            return null;
          }
        }

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

            String createdAtStr = item['created_at'] ?? '';
            DateTime createdAtDate = createdAtStr.isNotEmpty
                ? (parseKoreanDateTime(createdAtStr) ?? DateTime.now())
                : DateTime.now();

            return {
              'track_id': item['track_id']?.toString() ?? '',
              'username': item['username']?.toString() ?? '',
              'walkTime': _formatDuration(duration),
              'walkTimeDuration': duration,
              'distance': (distance / 1000).toStringAsFixed(2),
              'distanceValue': distance / 1000,
              'speed': speedValue.toStringAsFixed(2),
              'speedValue': speedValue,
              'created_at': createdAtDate.toIso8601String(),
              'date': createdAtDate,
            };
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

  void _calculateMonthlyTotals() {
    try {
      final int currentMonth = _focusedDay.month;
      final int currentYear = _focusedDay.year;

      Duration totalDuration = Duration();
      double totalDistance = 0.0;
      double totalSpeedSum = 0.0;
      int speedCount = 0;

      for (var item in workItems) {
        DateTime itemDate = item['date'];
        if (itemDate.month == currentMonth && itemDate.year == currentYear) {
          totalDuration += item['walkTimeDuration'] as Duration;
          totalDistance += item['distanceValue'] as double;
          totalSpeedSum += (item['speedValue'] as num).toDouble();
          speedCount++;
        }
      }

      double averageSpeed = speedCount > 0 ? totalSpeedSum / speedCount : 0.0;

      setState(() {
        _monthlyTotalWalkTime = _formatDuration(totalDuration);
        _monthlyTotalDistance = totalDistance.toStringAsFixed(2);
        _monthlyTotalSpeed = averageSpeed.toStringAsFixed(2); // 소수점 둘째 자리
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        toolbarHeight: MediaQuery.of(context).size.height * 0.05,
        leading: GestureDetector(
          onTap: () => Navigator.pop(context),
          child: Image.asset('assets/images/back.png'),
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
          : Column(
              children: [
                _buildCalendar(),
                _buildMonthlyTotalSection(),
                Expanded(
                  child: _buildSelectedDayWorkouts(),
                ),
              ],
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
                '평균 속력',
                '${double.parse(_monthlyTotalSpeed).toStringAsFixed(2)} km/h',
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
                    fontSize: 12,
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
      child: TableCalendar(
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
        ),
        headerStyle: HeaderStyle(
          formatButtonVisible: true,
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
      return Center(
        child: Text(
          '이 날의 산책 기록이 없습니다.',
          style: TextStyle(color: Colors.grey[600], fontSize: 16),
        ),
      );
    }

    return ListView.builder(
      padding: EdgeInsets.all(16),
      itemCount: selectedWorkouts.length,
      itemBuilder: (context, index) {
        final workout = selectedWorkouts[index];
        return Padding(
          padding: EdgeInsets.only(bottom: 16),
          child: WorkListItem(
            walkTime: workout['walkTime'],
            distance: workout['distance'],
            speed: workout['speed'],
            username: workout['username'],
            createdAt: _formatDisplayDate(workout['created_at']),
            onDelete: () => _showDeleteConfirmation(workout),
          ),
        );
      },
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
  final VoidCallback? onDelete;

  const WorkListItem({
    required this.walkTime,
    required this.distance,
    required this.speed,
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
                    Icons.delete_outline,
                    color: Colors.grey,
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
          backgroundImage:
              NetworkImage('https://i.imgur.com/qgaYJWX.png'), // 기본 강아지 이미지
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
