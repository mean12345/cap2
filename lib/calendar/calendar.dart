import 'package:flutter/material.dart';
import 'package:table_calendar/table_calendar.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:async';

class Event {
  final int eventId;
  final String title;
  final DateTime startDate;
  final DateTime endDate;
  final TimeOfDay startTime;
  final TimeOfDay endTime;
  final Color color;
  final bool isAllDay;

  Event({
    required this.eventId,
    required this.title,
    required this.startDate,
    required this.endDate,
    required this.startTime,
    required this.endTime,
    required this.color,
    required this.isAllDay,
  });

  factory Event.fromJson(Map<String, dynamic> json) {
    // 날짜 파싱
    final startDate = DateTime.parse(json['start_date']).toLocal();
    final endDate = DateTime.parse(json['end_date']).toLocal();

    // 시간 파싱
    final startTimeParts = json['start_time'].split(':');
    final endTimeParts = json['end_time'].split(':');

    final startTime = TimeOfDay(
      hour: int.parse(startTimeParts[0]),
      minute: int.parse(startTimeParts[1]),
    );

    final endTime = TimeOfDay(
      hour: int.parse(endTimeParts[0]),
      minute: int.parse(endTimeParts[1]),
    );

    // all_day 필드 처리 (1은 true, 0은 false)
    final isAllDay = json['all_day'] == 1;

    return Event(
      eventId: json['event_id'],
      title: json['title'],
      startDate: startDate,
      endDate: endDate,
      startTime: startTime,
      endTime: endTime,
      color: Color(int.parse('0xFF${json['color']}')),
      isAllDay: isAllDay, // all_day 필드 값 설정
    );
  }

  @override
  String toString() => title;
}

class CalendarPage extends StatefulWidget {
  final String username;
  const CalendarPage({
    super.key,
    required this.username,
  });

  @override
  _CalendarPageState createState() => _CalendarPageState();
}

class _CalendarPageState extends State<CalendarPage> {
  CalendarFormat _calendarFormat = CalendarFormat.month;
  DateTime _focusedDay = DateTime.now();
  DateTime? _selectedDay;

  Future<void> updateEvent({
    required int eventId,
    required String title,
    required String startDate,
    required String endDate,
    required String startTime,
    required String endTime,
    required String color,
    required bool allDay,
    required BuildContext context,
  }) async {
    final url = Uri.parse('$baseUrl/calendar/edit/$eventId');

    final response = await http.put(
      url,
      headers: {"Content-Type": "application/json"},
      body: jsonEncode({
        "title": title,
        "start_date": startDate,
        "end_date": endDate,
        "start_time": startTime,
        "end_time": endTime,
        "color": color,
        "all_day": allDay ? 1 : 0, // boolean을 0/1로 변환
      }),
    );

    if (response.statusCode == 200) {
      print("✅ 일정이 수정되었습니다.");
      Navigator.pop(context);
      // 일정 수정 후 캘린더 새로고침
      _fetchAllEvents();

      // 선택적: 성공 메시지 표시
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('일정이 수정되었습니다.')),
      );
    } else {
      print("❌ 일정 수정 실패: ${response.body}");

      // 선택적: 에러 메시지 표시
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('일정 수정에 실패했습니다: ${response.body}')),
      );
    }
  }

  final Map<DateTime, List<Event>> _events = {};
  List<Event> _getEventsForDay(DateTime day) {
    List<Event> eventsForDay = [];
    _events.forEach((date, events) {
      eventsForDay.addAll(events.where((event) {
        final eventStart = DateTime(
            event.startDate.year, event.startDate.month, event.startDate.day);
        final eventEnd = DateTime(
            event.endDate.year, event.endDate.month, event.endDate.day);
        final currentDay = DateTime(day.year, day.month, day.day);

        return (eventStart.isAtSameMomentAs(currentDay) ||
            eventEnd.isAtSameMomentAs(currentDay) ||
            (eventStart.isBefore(currentDay) && eventEnd.isAfter(currentDay)));
      }));
    });
    return eventsForDay;
  }

  final String baseUrl = dotenv.get('BASE_URL');
// 일정 삭제 함수
  Future<void> _deleteEvent(int eventId) async {
    final response = await http.delete(
      Uri.parse('$baseUrl/calendar/${widget.username}/delete/$eventId'),
    );

    if (response.statusCode == 200) {
      print('Event deleted successfully');
      // 일정 삭제 후 캘린더 새로고침
      _fetchAllEvents();
    } else {
      print('Failed to delete event. Status code: ${response.statusCode}');
    }
  }

  Future<List<Event>> _fetchEventsForDay(DateTime selectedDate) async {
    try {
      final startDateParam = '${selectedDate.year}-'
          '${selectedDate.month.toString().padLeft(2, '0')}-'
          '${selectedDate.day.toString().padLeft(2, '0')}';
      final endDateParam = startDateParam;

      final url =
          '$baseUrl/calendar/${widget.username}/events?start_date=$startDateParam&end_date=$endDateParam';

      final response = await http.get(Uri.parse(url));
      print('Response body: ${response.body}');
      print('url: ${url}');

      if (response.statusCode == 200) {
        final List jsonEvents = json.decode(response.body);
        return jsonEvents.map((json) {
          return Event.fromJson(json);
        }).toList();
      } else {
        throw Exception('서버 응답 오류: ${response.statusCode}');
      }
    } catch (e) {
      print('이벤트 로딩 중 오류: $e');
      throw Exception('이벤트 로딩 실패');
    }
  }

  @override
  void initState() {
    super.initState();
    _selectedDay = _focusedDay;
    _fetchAllEvents();
  }

  Future<void> _fetchAllEvents() async {
    try {
      // 현재 달의 시작일과 마지막일을 구합니다
      final firstDay =
          DateTime(_focusedDay.year, _focusedDay.month, 1).toLocal();
      final lastDay =
          DateTime(_focusedDay.year, _focusedDay.month + 1, 0).toLocal();

      final startDateParam = '${firstDay.year}-'
          '${firstDay.month.toString().padLeft(2, '0')}-'
          '${firstDay.day.toString().padLeft(2, '0')}';

      final endDateParam = '${lastDay.year}-'
          '${lastDay.month.toString().padLeft(2, '0')}-'
          '${lastDay.day.toString().padLeft(2, '0')}';

      final url =
          '$baseUrl/calendar/${widget.username}/events?start_date=$startDateParam&end_date=$endDateParam';
      final response = await http.get(Uri.parse(url));

      if (response.statusCode == 200) {
        final List jsonEvents = json.decode(response.body);
        final events = jsonEvents.map((json) => Event.fromJson(json)).toList();

        setState(() {
          _events.clear();
          for (var event in events) {
            // event.startDate는 이미 local 시간이므로 추가 변환 불필요
            final eventDate = DateTime(
              event.startDate.year,
              event.startDate.month,
              event.startDate.day,
            );

            if (_events[eventDate] == null) {
              _events[eventDate] = [];
            }
            _events[eventDate]!.add(event);
          }
        });
      }
    } catch (e) {
      print('이벤트 로딩 중 오류: $e');
    }
  }

  //  일정 색상 리스트
  final List<Color> _colors = [
    const Color.fromARGB(255, 124, 154, 179),
    const Color.fromARGB(255, 184, 78, 71),
    const Color.fromARGB(255, 106, 163, 108),
    const Color.fromARGB(255, 170, 146, 48),
    const Color.fromARGB(255, 157, 97, 168),
    const Color.fromARGB(255, 171, 171, 171),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      resizeToAvoidBottomInset: false,
      appBar: AppBar(
        backgroundColor: Colors.white,
        scrolledUnderElevation: 0,
        surfaceTintColor: Colors.transparent,
        leading: IconButton(
          icon: Icon(Icons.arrow_back),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: const Text(
          '캘린더',
          style: TextStyle(
            color: Colors.black,
            fontSize: 18,
            fontWeight: FontWeight.w500,
          ),
        ),
      ),
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            return Stack(
              children: [
                Column(
                  children: [
                    Container(
                      height: constraints.maxHeight * 0.8,
                      color: Colors.white,
                      child: TableCalendar(
                        firstDay: DateTime.utc(2020, 1, 1),
                        lastDay: DateTime.utc(2030, 12, 31),
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
                          if (_calendarFormat != format) {
                            setState(() {
                              _calendarFormat = format;
                            });
                          }
                        },
                        onPageChanged: (focusedDay) {
                          setState(() {
                            _focusedDay = focusedDay;
                          });
                          _fetchAllEvents(); // 페이지 변경 시 해당 월의 이벤트 가져오기
                        },
                        rowHeight: 60,
                        daysOfWeekHeight: 20,
                        calendarStyle: CalendarStyle(
                          todayDecoration: BoxDecoration(
                            color: Colors.transparent,
                          ),
                          selectedDecoration: BoxDecoration(
                            color: Colors.transparent,
                          ),
                          todayTextStyle: TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                          ),
                          selectedTextStyle: TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                          ),
                          cellMargin: EdgeInsets.all(1),
                          cellPadding: EdgeInsets.zero,
                          markersMaxCount: 4,
                          markersAlignment: Alignment.bottomCenter,
                        ),
                        headerStyle: HeaderStyle(
                          formatButtonVisible: false,
                          titleCentered: true,
                          titleTextFormatter: (date, locale) {
                            return '${date.year}년 ${date.month}월';
                          },
                        ),
                        daysOfWeekStyle: DaysOfWeekStyle(
                          weekdayStyle: TextStyle(color: Colors.black),
                          weekendStyle: TextStyle(color: Colors.red),
                        ),
                        calendarBuilders: CalendarBuilders(
                          todayBuilder: (context, date, _) {
                            return Center(
                              child: Container(
                                width: 20,
                                height: 20,
                                decoration: BoxDecoration(
                                  color: Colors.grey,
                                  shape: BoxShape.circle,
                                ),
                                child: Center(
                                  child: Text(
                                    '${date.day}',
                                    style: TextStyle(color: Colors.white),
                                  ),
                                ),
                              ),
                            );
                          },
                          selectedBuilder: (context, date, _) {
                            return Center(
                              child: Container(
                                width: 20,
                                height: 20,
                                decoration: BoxDecoration(
                                  color: Colors.green,
                                  shape: BoxShape.circle,
                                ),
                                child: Center(
                                  child: Text(
                                    '${date.day}',
                                    style: TextStyle(color: Colors.white),
                                  ),
                                ),
                              ),
                            );
                          },
                          markerBuilder: (context, date, events) {
                            if (events.isNotEmpty) {
                              final eventsList = events as List<Event>;
                              // 최대 5개의 마커만 표시
                              final displayEvents = eventsList.take(5).toList();
                              return Positioned(
                                bottom: 1,
                                left: 0,
                                right: 0,
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: displayEvents.map((event) {
                                    return Container(
                                      width: 6,
                                      height: 6,
                                      margin: const EdgeInsets.symmetric(
                                          horizontal: 1),
                                      decoration: BoxDecoration(
                                        color: event.color.withOpacity(0.7),
                                        shape: BoxShape.circle,
                                      ),
                                    );
                                  }).toList(),
                                ),
                              );
                            }
                            return null;
                          },
                          dowBuilder: (context, day) {
                            final text = [
                              '일',
                              '월',
                              '화',
                              '수',
                              '목',
                              '금',
                              '토'
                            ][day.weekday % 7];
                            if (day.weekday == DateTime.sunday) {
                              return Center(
                                child: Text(
                                  text,
                                  style: TextStyle(color: Colors.red),
                                ),
                              );
                            }
                            if (day.weekday == DateTime.saturday) {
                              return Center(
                                child: Text(
                                  text,
                                  style: TextStyle(color: Colors.blue),
                                ),
                              );
                            }
                            return Center(
                              child: Text(
                                text,
                                style: TextStyle(color: Colors.black),
                              ),
                            );
                          },
                        ),
                        eventLoader: _getEventsForDay,
                        availableGestures: AvailableGestures.horizontalSwipe,
                      ),
                    ),
                    Divider(
                      height: 1,
                      thickness: 1,
                      color: Colors.grey[300],
                    ),
                  ],
                ),
                DraggableScrollableSheet(
                  // 스크롤 시 팝업 창
                  initialChildSize: 0.4,
                  minChildSize: 0.2,
                  maxChildSize: 0.7,
                  builder: (context, scrollController) {
                    return Container(
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius:
                            BorderRadius.vertical(top: Radius.circular(16.0)),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black26, // 그림자 색상
                            blurRadius: 1.0, // 그림자 흐림 정도
                            spreadRadius: 1.0, // 그림자 확산 정도
                          ),
                        ],
                      ),
                      child: ListView(
                        // 스크롤 시 팝업 창 내용
                        controller: scrollController,
                        children: [
                          Padding(
                            // 팝업 창 내용 패딩
                            padding: const EdgeInsets.all(12.0),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  _selectedDay != null
                                      ? '${_selectedDay!.year}.${_selectedDay!.month}.${_selectedDay!.day}'
                                      : '날짜를 선택해주세요',
                                  style: const TextStyle(
                                    fontSize: 18, // 폰트 크기
                                    fontWeight: FontWeight.bold, // 폰트 굵기
                                  ),
                                ),
                                IconButton(
                                  icon: const Icon(Icons.add), // 추가 버튼 아이콘
                                  onPressed: () {
                                    _showAddEventDialog();
                                  },
                                ),
                              ],
                            ),
                          ),
                          Divider(
                            // 구분선
                            height: 1,
                            thickness: 1,
                            color: Colors.grey[300],
                          ),
                          FutureBuilder<List<Event>>(
                            future: _selectedDay != null
                                ? _fetchEventsForDay(_selectedDay!)
                                : Future.value(
                                    []), // selectedDay가 null이면 빈 리스트 반환
                            builder: (context, snapshot) {
                              if (snapshot.connectionState ==
                                  ConnectionState.waiting) {
                                return Center(
                                    child: CircularProgressIndicator());
                              } else if (snapshot.hasError) {
                                return Center(
                                    child: Text('일정을 불러오는 데 실패했습니다.'));
                              } else if (snapshot.hasData) {
                                final eventsForDay = snapshot.data!;

                                final filteredEvents =
                                    eventsForDay.where((event) {
                                  final eventStart = event.startDate;
                                  final eventEnd = event.endDate;
                                  final selectedDate = DateTime(
                                    _selectedDay!.year,
                                    _selectedDay!.month,
                                    _selectedDay!.day,
                                  );

                                  return (selectedDate.isAfter(eventStart
                                          .subtract(Duration(days: 1))) &&
                                      selectedDate.isBefore(
                                          eventEnd.add(Duration(days: 1))));
                                }).toList();

                                return Column(
                                  children: filteredEvents
                                      .map((event) => ListTile(
                                            leading: Container(
                                              width: 12,
                                              height: 12,
                                              decoration: BoxDecoration(
                                                color: event.color,
                                                shape: BoxShape.circle,
                                              ),
                                            ),
                                            title: Text(event.title),
                                            subtitle: Column(
                                              crossAxisAlignment:
                                                  CrossAxisAlignment.start,
                                              children: [
                                                Text(
                                                  event.isAllDay
                                                      ? '하루 종일'
                                                      : event.startDate
                                                                  .toLocal()
                                                                  .day ==
                                                              event.endDate
                                                                  .toLocal()
                                                                  .day
                                                          ? '${event.startDate.toLocal().month.toString().padLeft(2, '0')}.${event.startDate.toLocal().day.toString().padLeft(2, '0')}'
                                                          : '${event.startDate.toLocal().month.toString().padLeft(2, '0')}.${event.startDate.toLocal().day.toString().padLeft(2, '0')} - '
                                                              '${event.endDate.toLocal().month.toString().padLeft(2, '0')}.${event.endDate.toLocal().day.toString().padLeft(2, '0')}',
                                                ),
                                                if (!event.isAllDay)
                                                  Text(
                                                    '${event.startTime.hour.toString().padLeft(2, '0')}:${event.startTime.minute.toString().padLeft(2, '0')} - '
                                                    '${event.endTime.hour.toString().padLeft(2, '0')}:${event.endTime.minute.toString().padLeft(2, '0')}',
                                                  ),
                                              ],
                                            ),
                                            trailing: IconButton(
                                              icon: Icon(Icons.delete,
                                                  color: Colors.red),
                                              onPressed: () {
                                                showDialog(
                                                  context: context,
                                                  builder: (context) => Dialog(
                                                    shape:
                                                        RoundedRectangleBorder(
                                                      borderRadius:
                                                          BorderRadius.circular(
                                                              5),
                                                    ),
                                                    child: Container(
                                                      padding:
                                                          EdgeInsets.all(20),
                                                      decoration: BoxDecoration(
                                                        color: Colors.white,
                                                        borderRadius:
                                                            BorderRadius
                                                                .circular(5),
                                                      ),
                                                      child: Column(
                                                        mainAxisSize:
                                                            MainAxisSize.min,
                                                        children: [
                                                          Text(
                                                            '삭제 확인',
                                                            style: TextStyle(
                                                              fontSize: 18,
                                                              fontWeight:
                                                                  FontWeight
                                                                      .bold,
                                                            ),
                                                          ),
                                                          SizedBox(height: 25),
                                                          Text(
                                                              '이 일정을 삭제하시겠습니까?'),
                                                          SizedBox(height: 20),
                                                          Row(
                                                            mainAxisAlignment:
                                                                MainAxisAlignment
                                                                    .center,
                                                            children: [
                                                              TextButton(
                                                                child: Text(
                                                                  '취소',
                                                                  style: TextStyle(
                                                                      color: Colors
                                                                          .grey),
                                                                ),
                                                                onPressed: () =>
                                                                    Navigator.pop(
                                                                        context),
                                                              ),
                                                              SizedBox(
                                                                  width: 30),
                                                              TextButton(
                                                                child: Text(
                                                                  '삭제',
                                                                  style: TextStyle(
                                                                      color: Color.fromARGB(
                                                                          255,
                                                                          124,
                                                                          172,
                                                                          117)),
                                                                ),
                                                                onPressed: () {
                                                                  setState(() {
                                                                    _deleteEvent(event
                                                                            .eventId)
                                                                        .then(
                                                                            (_) {
                                                                      final eventDate =
                                                                          DateTime(
                                                                        event
                                                                            .startDate
                                                                            .year,
                                                                        event
                                                                            .startDate
                                                                            .month,
                                                                        event
                                                                            .startDate
                                                                            .day,
                                                                      );
                                                                      _events[eventDate]
                                                                          ?.remove(
                                                                              event);
                                                                      if (_events[eventDate]
                                                                              ?.isEmpty ??
                                                                          false) {
                                                                        _events.remove(
                                                                            eventDate);
                                                                      }
                                                                    });
                                                                    Navigator.pop(
                                                                        context);
                                                                  });
                                                                },
                                                              ),
                                                            ],
                                                          ),
                                                        ],
                                                      ),
                                                    ),
                                                  ),
                                                );
                                              },
                                            ),
                                            onTap: () =>
                                                _showEditEventDialog(event),
                                          ))
                                      .toList(),
                                );
                              } else {
                                return Center(child: Text('일정이 없습니다.'));
                              }
                            },
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  void _showAddEventDialog() {
    final TextEditingController _titleController = TextEditingController();
    bool _isAllDay = false;
    DateTime _startDate = _selectedDay ?? DateTime.now();
    DateTime _endDate = _selectedDay ?? DateTime.now();
    TimeOfDay _startTime = TimeOfDay.now();
    TimeOfDay _endTime = TimeOfDay.now();
    Color _selectedColor = Colors.blue;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => Dialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(5),
          ),
          child: Container(
            padding: EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(5),
            ),
            constraints: BoxConstraints(
              maxHeight: MediaQuery.of(context).size.height * 0.8,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  '일정 추가',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                SizedBox(height: 25),
                Flexible(
                  child: SingleChildScrollView(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: TextField(
                                controller: _titleController,
                                decoration: InputDecoration(
                                  labelText: '제목',
                                  labelStyle:
                                      TextStyle(color: Color(0xFF4DA374)),
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(5),
                                  ),
                                  focusedBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(5),
                                    borderSide:
                                        BorderSide(color: Color(0xFF4DA374)),
                                  ),
                                  enabledBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(5),
                                    borderSide:
                                        BorderSide(color: Color(0xFF4DA374)),
                                  ),
                                ),
                              ),
                            ),
                            SizedBox(width: 8),
                            InkWell(
                              onTap: () {
                                _showColorPicker(context, (color) {
                                  setState(() => _selectedColor = color);
                                });
                              },
                              child: Container(
                                width: 30,
                                height: 30,
                                decoration: BoxDecoration(
                                  color: _selectedColor,
                                  shape: BoxShape.circle,
                                ),
                              ),
                            ),
                          ],
                        ),
                        SizedBox(height: 16),
                        Row(
                          children: [
                            Text('하루 종일'),
                            Spacer(),
                            Switch(
                              value: _isAllDay,
                              onChanged: (value) {
                                setState(() {
                                  _isAllDay = value;
                                });
                              },
                              activeColor: Color(0xFF4DA374),
                              inactiveTrackColor: Color(0xFFE0E0E0),
                              inactiveThumbColor: Colors.grey[400],
                            ),
                          ],
                        ),
                        SizedBox(height: 16),
                        Text('시작',
                            style: TextStyle(fontWeight: FontWeight.bold)),
                        Row(
                          children: [
                            Expanded(
                              child: TextButton(
                                onPressed: () async {
                                  final DateTime? date = await showDatePicker(
                                    context: context,
                                    initialDate: _startDate,
                                    firstDate: DateTime(2020),
                                    lastDate: DateTime(2030),
                                    builder:
                                        (BuildContext context, Widget? child) {
                                      return Theme(
                                        data: ThemeData.light().copyWith(
                                          primaryColor: Color(0xFF4DA374),
                                          colorScheme: ColorScheme.light(
                                              primary: Color(0xFF4DA374)),
                                          buttonTheme: ButtonThemeData(
                                              textTheme:
                                                  ButtonTextTheme.primary),
                                          dialogBackgroundColor: Colors.white,
                                        ),
                                        child: child!,
                                      );
                                    },
                                  );
                                  if (date != null) {
                                    setState(() {
                                      _startDate = date;
                                      if (_endDate.isBefore(_startDate)) {
                                        _endDate = _startDate;
                                      }
                                    });
                                  }
                                },
                                child: Text(
                                  '${_startDate.year}.${_startDate.month}.${_startDate.day}',
                                  style: TextStyle(
                                      fontSize: 16, color: Colors.black),
                                ),
                              ),
                            ),
                            if (!_isAllDay) ...[
                              Icon(Icons.access_time, size: 20),
                              SizedBox(width: 8),
                              TextButton(
                                onPressed: () async {
                                  final TimeOfDay? time =
                                      await _showCustomTimePicker(
                                    context,
                                    _startTime,
                                  );
                                  if (time != null) {
                                    setState(() {
                                      _startTime = time;
                                    });
                                  }
                                },
                                child: Text(
                                  '${_startTime.format(context)}',
                                  style: TextStyle(
                                      fontSize: 16, color: Colors.black),
                                ),
                              ),
                            ],
                          ],
                        ),
                        SizedBox(height: 16),
                        Text('종료',
                            style: TextStyle(fontWeight: FontWeight.bold)),
                        Row(
                          children: [
                            Expanded(
                              child: TextButton(
                                onPressed: () async {
                                  final DateTime? date = await showDatePicker(
                                    context: context,
                                    initialDate: _endDate,
                                    firstDate: _startDate,
                                    lastDate: DateTime(2030),
                                    builder:
                                        (BuildContext context, Widget? child) {
                                      return Theme(
                                        data: ThemeData.light().copyWith(
                                          primaryColor: Color(0xFF4DA374),
                                          colorScheme: ColorScheme.light(
                                              primary: Color(0xFF4DA374)),
                                          buttonTheme: ButtonThemeData(
                                              textTheme:
                                                  ButtonTextTheme.primary),
                                          dialogBackgroundColor: Colors.white,
                                        ),
                                        child: child!,
                                      );
                                    },
                                  );
                                  if (date != null) {
                                    setState(() {
                                      _endDate = date;
                                    });
                                  }
                                },
                                child: Text(
                                  '${_endDate.year}.${_endDate.month}.${_endDate.day}',
                                  style: TextStyle(
                                      fontSize: 16, color: Colors.black),
                                ),
                              ),
                            ),
                            if (!_isAllDay) ...[
                              Icon(Icons.access_time, size: 20),
                              SizedBox(width: 8),
                              TextButton(
                                onPressed: () async {
                                  final TimeOfDay? time =
                                      await _showCustomTimePicker(
                                          context, _endTime);
                                  if (time != null) {
                                    setState(() {
                                      _endTime = time;
                                    });
                                  }
                                },
                                child: Text(
                                  '${_endTime.format(context)}',
                                  style: TextStyle(
                                      fontSize: 16, color: Colors.black),
                                ),
                              ),
                            ],
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
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
                        '저장',
                        style: TextStyle(color: Color(0xFF4DA374)),
                      ),
                      onPressed: () async {
                        if (_titleController.text.isEmpty) return;

                        final eventStartDate =
                            "${_startDate.year}-${_startDate.month}-${_startDate.day}";
                        final eventEndDate =
                            "${_endDate.year}-${_endDate.month}-${_endDate.day}";
                        final eventStartTime =
                            "${_startTime.hour}:${_startTime.minute}:00";
                        final eventEndTime =
                            "${_endTime.hour}:${_endTime.minute}:00";

                        final isAllDay = _isAllDay;

                        final eventData = {
                          "username": widget.username,
                          "title": _titleController.text,
                          "start_date": eventStartDate,
                          "end_date": eventEndDate,
                          "start_time": eventStartTime,
                          "end_time": eventEndTime,
                          "color": _selectedColor.value.toRadixString(16),
                          "all_day": isAllDay,
                        };

                        try {
                          final String baseUrl = dotenv.get('BASE_URL');

                          final response = await http.post(
                            Uri.parse("$baseUrl/calendar"),
                            headers: {"Content-Type": "application/json"},
                            body: jsonEncode(eventData),
                          );

                          if (response.statusCode == 201) {
                            print("일정이 성공적으로 추가되었습니다.");
                            Navigator.pop(context);
                            _fetchAllEvents();
                          } else {
                            print("일정 추가 실패: ${response.body}");
                          }
                        } catch (error) {
                          print("서버 요청 오류: $error");
                        }
                      },
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _showEditEventDialog(Event event) {
    final TextEditingController _titleController =
        TextEditingController(text: event.title);
    bool _isAllDay = event.isAllDay;
    DateTime _startDate = event.startDate;
    DateTime _endDate = event.endDate;
    // TimeOfDay 초기화 수정
    TimeOfDay _startTime = event.startTime; // TimeOfDay는 이미 Event 클래스에서 정의되어 있음
    TimeOfDay _endTime = event.endTime; // startDate.hour 대신 직접 TimeOfDay 사용
    Color _selectedColor = event.color;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => Dialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(5),
          ),
          child: Container(
            padding: EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(5),
            ),
            constraints: BoxConstraints(
              maxHeight: MediaQuery.of(context).size.height * 0.8,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  '일정 수정',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                SizedBox(height: 25),
                Flexible(
                  child: SingleChildScrollView(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: TextField(
                                controller: _titleController,
                                decoration: InputDecoration(
                                  labelText: '제목',
                                  labelStyle:
                                      TextStyle(color: Color(0xFF4DA374)),
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(5),
                                  ),
                                  focusedBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(5),
                                    borderSide:
                                        BorderSide(color: Color(0xFF4DA374)),
                                  ),
                                  enabledBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(5),
                                    borderSide:
                                        BorderSide(color: Color(0xFF4DA374)),
                                  ),
                                ),
                              ),
                            ),
                            SizedBox(width: 8),
                            InkWell(
                              onTap: () {
                                _showColorPicker(context, (color) {
                                  setState(() => _selectedColor = color);
                                });
                              },
                              child: Container(
                                width: 30,
                                height: 30,
                                decoration: BoxDecoration(
                                  color: _selectedColor,
                                  shape: BoxShape.circle,
                                ),
                              ),
                            ),
                          ],
                        ),
                        SizedBox(height: 16),
                        Row(
                          children: [
                            Text('하루 종일'),
                            Spacer(),
                            Switch(
                              value: _isAllDay,
                              onChanged: (value) {
                                setState(() {
                                  _isAllDay = value;
                                });
                              },
                              activeColor: Color(0xFF4DA374),
                              inactiveTrackColor: Color(0xFFE0E0E0),
                              inactiveThumbColor: Colors.grey[400],
                            ),
                          ],
                        ),
                        SizedBox(height: 16),
                        Text('시작',
                            style: TextStyle(fontWeight: FontWeight.bold)),
                        Row(
                          children: [
                            Expanded(
                              child: TextButton(
                                onPressed: () async {
                                  final DateTime? date = await showDatePicker(
                                    context: context,
                                    initialDate: _startDate,
                                    firstDate: DateTime(2020),
                                    lastDate: DateTime(2030),
                                    builder:
                                        (BuildContext context, Widget? child) {
                                      return Theme(
                                        data: ThemeData.light().copyWith(
                                          primaryColor: Color(0xFF4DA374),
                                          colorScheme: ColorScheme.light(
                                              primary: Color(0xFF4DA374)),
                                          buttonTheme: ButtonThemeData(
                                              textTheme:
                                                  ButtonTextTheme.primary),
                                          dialogBackgroundColor: Colors.white,
                                        ),
                                        child: child!,
                                      );
                                    },
                                  );
                                  if (date != null) {
                                    setState(() {
                                      _startDate = date;
                                      if (_endDate.isBefore(_startDate)) {
                                        _endDate = _startDate;
                                      }
                                    });
                                  }
                                },
                                child: Text(
                                  '${_startDate.year}.${_startDate.month}.${_startDate.day}',
                                  style: TextStyle(
                                      fontSize: 16, color: Colors.black),
                                ),
                              ),
                            ),
                            if (!_isAllDay) ...[
                              Icon(Icons.access_time, size: 20),
                              SizedBox(width: 8),
                              TextButton(
                                onPressed: () async {
                                  final TimeOfDay? time =
                                      await _showCustomTimePicker(
                                    context,
                                    _startTime,
                                  );
                                  if (time != null) {
                                    setState(() {
                                      _startTime = time;
                                    });
                                  }
                                },
                                child: Text(
                                  '${_startTime.format(context)}',
                                  style: TextStyle(
                                      fontSize: 16, color: Colors.black),
                                ),
                              ),
                            ],
                          ],
                        ),
                        SizedBox(height: 16),
                        Text('종료',
                            style: TextStyle(fontWeight: FontWeight.bold)),
                        Row(
                          children: [
                            Expanded(
                              child: TextButton(
                                onPressed: () async {
                                  final DateTime? date = await showDatePicker(
                                    context: context,
                                    initialDate: _endDate,
                                    firstDate: _startDate,
                                    lastDate: DateTime(2030),
                                    builder:
                                        (BuildContext context, Widget? child) {
                                      return Theme(
                                        data: ThemeData.light().copyWith(
                                          primaryColor: Color(0xFF4DA374),
                                          colorScheme: ColorScheme.light(
                                              primary: Color(0xFF4DA374)),
                                          buttonTheme: ButtonThemeData(
                                              textTheme:
                                                  ButtonTextTheme.primary),
                                          dialogBackgroundColor: Colors.white,
                                        ),
                                        child: child!,
                                      );
                                    },
                                  );
                                  if (date != null) {
                                    setState(() {
                                      _endDate = date;
                                    });
                                  }
                                },
                                child: Text(
                                  '${_endDate.year}.${_endDate.month}.${_endDate.day}',
                                  style: TextStyle(
                                      fontSize: 16, color: Colors.black),
                                ),
                              ),
                            ),
                            if (!_isAllDay) ...[
                              Icon(Icons.access_time, size: 20),
                              SizedBox(width: 8),
                              TextButton(
                                onPressed: () async {
                                  final TimeOfDay? time =
                                      await _showCustomTimePicker(
                                          context, _endTime);
                                  if (time != null) {
                                    setState(() {
                                      _endTime = time;
                                    });
                                  }
                                },
                                child: Text(
                                  '${_endTime.format(context)}',
                                  style: TextStyle(
                                      fontSize: 16, color: Colors.black),
                                ),
                              ),
                            ],
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
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
                        '저장',
                        style: TextStyle(color: Color(0xFF4DA374)),
                      ),
                      onPressed: () async {
                        if (_titleController.text.isEmpty) return;

                        final eventStartDate =
                            "${_startDate.year}-${_startDate.month}-${_startDate.day}";
                        final eventEndDate =
                            "${_endDate.year}-${_endDate.month}-${_endDate.day}";
                        final eventStartTime =
                            "${_startTime.hour}:${_startTime.minute}:00";
                        final eventEndTime =
                            "${_endTime.hour}:${_endTime.minute}:00";

                        final isAllDay = _isAllDay;

                        await updateEvent(
                          eventId: event.eventId,
                          title: _titleController.text,
                          startDate: eventStartDate,
                          endDate: eventEndDate,
                          startTime: eventStartTime,
                          endTime: eventEndTime,
                          color: _selectedColor.value.toRadixString(16),
                          allDay: isAllDay,
                          context: context,
                        );
                      },
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _showColorPicker(BuildContext context, Function(Color) onColorSelected) {
    showDialog(
      context: context,
      builder: (context) => Dialog(
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
                '색상 선택',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              SizedBox(height: 25),
              Container(
                width: 200,
                child: GridView.count(
                  crossAxisCount: 3,
                  mainAxisSpacing: 8,
                  crossAxisSpacing: 8,
                  shrinkWrap: true,
                  children: _colors
                      .map((color) => InkWell(
                            onTap: () {
                              onColorSelected(color);
                              Navigator.pop(context);
                            },
                            child: Container(
                              decoration: BoxDecoration(
                                color: color,
                                shape: BoxShape.circle,
                              ),
                            ),
                          ))
                      .toList(),
                ),
              ),
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
                      '확인',
                      style: TextStyle(color: Color(0xFF4DA374)),
                    ),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<TimeOfDay?> _showCustomTimePicker(
      BuildContext context, TimeOfDay initialTime) {
    int selectedHour = initialTime.hour;
    int selectedMinute = initialTime.minute;
    String period = selectedHour >= 12 ? 'PM' : 'AM';

    if (selectedHour > 12) {
      selectedHour -= 12;
    } else if (selectedHour == 0) {
      selectedHour = 12;
    }

    return showDialog<TimeOfDay>(
      context: context,
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              contentPadding: EdgeInsets.zero,
              content: Container(
                width: 300,
                height: 400,
                decoration: BoxDecoration(
                  color: Colors.white,
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Expanded(
                      child: Row(
                        children: [
                          // 시간 선택
                          Expanded(
                            child: ListWheelScrollView(
                              itemExtent: 50,
                              diameterRatio: 1.5,
                              onSelectedItemChanged: (index) {
                                setState(() {
                                  selectedHour = index + 1;
                                });
                              },
                              children: List.generate(12, (index) {
                                return Center(
                                  child: Text(
                                    '${index + 1}'.padLeft(2, '0'),
                                    style: TextStyle(
                                      fontSize: 20,
                                      color: (index + 1) == selectedHour
                                          ? Colors.black
                                          : Colors.grey,
                                    ),
                                  ),
                                );
                              }),
                            ),
                          ),
                          // 분 선택
                          Expanded(
                            child: ListWheelScrollView(
                              itemExtent: 50,
                              diameterRatio: 1.5,
                              onSelectedItemChanged: (index) {
                                setState(() {
                                  selectedMinute = index;
                                });
                              },
                              children: List.generate(60, (index) {
                                return Center(
                                  child: Text(
                                    '$index'.padLeft(2, '0'),
                                    style: TextStyle(
                                      fontSize: 20,
                                      color: index == selectedMinute
                                          ? Colors.black
                                          : Colors.grey,
                                    ),
                                  ),
                                );
                              }),
                            ),
                          ),
                          // AM/PM 선택
                          Expanded(
                            child: ListWheelScrollView(
                              itemExtent: 50,
                              diameterRatio: 1.5,
                              onSelectedItemChanged: (index) {
                                setState(() {
                                  period = index == 0 ? 'AM' : 'PM';
                                });
                              },
                              children: ['AM', 'PM'].map((p) {
                                return Center(
                                  child: Text(
                                    p,
                                    style: TextStyle(
                                      fontSize: 20,
                                      color: p == period
                                          ? Colors.black
                                          : Colors.grey,
                                    ),
                                  ),
                                );
                              }).toList(),
                            ),
                          ),
                        ],
                      ),
                    ),
                    Divider(height: 1),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        TextButton(
                          child: Text(
                            '취소',
                            style: TextStyle(color: Colors.grey),
                          ),
                          onPressed: () => Navigator.pop(context),
                        ),
                        TextButton(
                          child: Text(
                            '확인',
                            style: TextStyle(color: Color(0xFF4DA374)),
                          ),
                          onPressed: () {
                            int hour = selectedHour;
                            if (period == 'PM' && hour != 12) {
                              hour += 12;
                            } else if (period == 'AM' && hour == 12) {
                              hour = 0;
                            }
                            Navigator.pop(
                              context,
                              TimeOfDay(hour: hour, minute: selectedMinute),
                            );
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
      },
    );
  }
}
