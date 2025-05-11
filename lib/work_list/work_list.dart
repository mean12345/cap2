import 'package:flutter/material.dart';
import '../colors.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:intl/intl.dart';

class WorkList extends StatefulWidget {
  final String username;
  const WorkList({required this.username, super.key});

  @override
  State<WorkList> createState() => _WorkListState();
}

class _WorkListState extends State<WorkList> {
  List<Map<String, dynamic>> workItems = [];
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    fetchWorkoutData();
    _fetchProfileInfo(widget.username);
  }

  final String baseUrl = dotenv.get('BASE_URL');

  Future<Map<String, String>> _fetchProfileInfo(String username) async {
    final String baseUrl = dotenv.get('BASE_URL');
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

  Future<void> fetchWorkoutData() async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/tracking/${widget.username}'),
      );

      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(response.body);
        setState(() {
          workItems = data.map((item) {
            try {
              DateTime? startTime = _parseKoreanDateTime(item['start_time']);
              DateTime? endTime = _parseKoreanDateTime(item['end_time']);

              Duration duration = Duration();

              if (startTime != null && endTime != null) {
                duration = endTime.difference(startTime);
                print(
                    'start: $startTime, end: $endTime, duration: ${duration.inSeconds}초');
              } else {
                print('start 또는 end가 null임. 아이템: $item');
              }

              int stepCount =
                  int.tryParse(item['step_count']?.toString() ?? '0') ?? 0;
              double distance =
                  double.tryParse(item['distance']?.toString() ?? '0') ?? 0;

              return {
                'track_id': item['track_id']?.toString() ?? '',
                'username': item['username']?.toString() ?? '',
                'walkTime': _formatDuration(duration),
                'distance': (distance / 1000).toStringAsFixed(2),
                'steps': stepCount.toString(),
                'created_at': item['created_at'] ??
                    DateTime.now().toString(), // toString() 사용
              };
            } catch (e) {
              print('Data processing error: $e');
              return {
                'track_id': item['track_id']?.toString() ?? '',
                'username': item['username']?.toString() ?? '',
                'walkTime': '00:00:00',
                'distance': '0.00',
                'steps': '0',
                'created_at': DateTime.now().toString().split(' ')[0],
              };
            }
          }).toList();
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
        });
      }
    } catch (e) {
      print('Error deleting workout: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Scaffold(
        backgroundColor: AppColors.background,
        appBar: AppBar(
          toolbarHeight: MediaQuery.of(context).size.height * 0.05,
          leading: GestureDetector(
            onTap: () => Navigator.pop(context),
            child: Image.asset('assets/images/back.png'),
          ),
          backgroundColor: Colors.transparent,
        ),
        body: isLoading
            ? Center(child: CircularProgressIndicator())
            : SingleChildScrollView(
                child: Padding(
                  padding: EdgeInsets.all(16.0),
                  child: _buildWorkoutList(),
                ),
              ),
      ),
    );
  }

  Widget _buildWorkoutList() {
    if (workItems.isEmpty) {
      return Center(child: Text('산책 기록이 없습니다.'));
    }

    List<Widget> listItems = [];

    for (var item in workItems) {
      listItems.add(_buildWorkListSection(item));
      listItems.add(SizedBox(height: 20));
    }

    return Column(children: listItems);
  }

  Widget _buildWorkListSection(Map<String, dynamic> item) {
    return WorkListItem(
      walkTime: item['walkTime'],
      distance: item['distance'],
      steps: item['steps'],
      username: item['username'],
      createdAt: _formatDate(item['created_at']),
      onDelete: () => _showDeleteConfirmation(item),
    );
  }

  String _formatDate(String dateString) {
    try {
      DateTime dateTime = DateTime.parse(dateString);
      return DateFormat('yyyy년 MM월 dd일').format(dateTime);
    } catch (e) {
      print('Date formatting error: $e');
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
      height: 230,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(5),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.3),
            spreadRadius: 2,
            blurRadius: 5,
            offset: Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        children: [
          _buildHeaderSection(),
          _buildContentSection(),
        ],
      ),
    );
  }

  Future<Map<String, String>> _fetchProfileInfo(String username) async {
    final String baseUrl = dotenv.get('BASE_URL');
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

  Widget _buildHeaderSection() {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 15),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    FutureBuilder<Map<String, String>>(
                      future: _fetchProfileInfo(
                          username), // username을 넘겨서 프로필 정보를 가져옵니다
                      builder: (context, snapshot) {
                        if (snapshot.connectionState ==
                            ConnectionState.waiting) {
                          return const Text('닉네임을 불러오는 중...');
                        } else if (snapshot.hasError) {
                          return const Text('닉네임을 불러오는 데 실패했습니다.');
                        } else if (snapshot.hasData) {
                          final profileInfo = snapshot.data!;
                          return Text(
                            profileInfo['nickname'] ?? '닉네임을 불러오는 중...',
                            style: const TextStyle(
                              color: Colors.black,
                              fontSize: 20,
                              fontWeight: FontWeight.w500,
                            ),
                          );
                        } else {
                          return const Text('닉네임을 불러오는 중...');
                        }
                      },
                    ),
                    const SizedBox(width: 10),
                    Padding(
                      padding: const EdgeInsets.only(top: 15),
                      child: Text(
                        createdAt,
                        style: const TextStyle(
                          fontSize: 10,
                          color: Colors.grey,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              GestureDetector(
                onTap: onDelete,
                child: const Icon(
                  Icons.delete_outline,
                  color: Colors.grey,
                  size: 24,
                ),
              )
            ],
          ),
        ),
        Container(
          height: 1,
          color: Colors.grey.withOpacity(0.3),
          margin: const EdgeInsets.only(
            top: 2,
            left: 15,
            right: 15,
            bottom: 20,
          ),
        ),
      ],
    );
  }

  Widget _buildContentSection() {
    return Padding(
      padding: EdgeInsets.only(top: 10),
      child: Column(
        children: [
          _buildInfoRow("산책 시간", walkTime.isNotEmpty ? walkTime : '00:00:00'),
          SizedBox(height: 15),
          _buildInfoRow("산책 거리", "$distance km"),
          SizedBox(height: 15),
          _buildInfoRow("걸 음 수", "$steps 걸음"),
        ],
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 20),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          SizedBox(
            width: 125,
            child: Padding(
              padding: EdgeInsets.only(left: 40),
              child: Text(
                label,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 16,
                  color: Colors.grey[600],
                ),
              ),
            ),
          ),
          Container(
            width: 20,
            alignment: Alignment.center,
            child: Text(
              ":",
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          Expanded(
            child: Padding(
              padding: EdgeInsets.only(left: 25, right: 15),
              child: Text(
                value,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
