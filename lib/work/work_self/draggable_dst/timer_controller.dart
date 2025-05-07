import 'dart:async';
import 'package:flutter/foundation.dart';

//산책 시간 관리 파일

class TimerController extends ValueNotifier<int> {
  Timer? _timer;
  bool _isRunning = false;
  bool _isPaused = false;
  int _lastElapsedTime = 0; // 일시정지 시점의 시간을 저장하기 위한 변수 추가

  TimerController() : super(0);

  bool get isRunning => _isRunning;
  bool get isPaused => _isPaused;
  int get elapsedTime => value;

  void startTimer() {
    if (_isRunning) return;

    _isRunning = true;
    _isPaused = false;
    _timer?.cancel();

    if (_lastElapsedTime > 0) {
      value = _lastElapsedTime; // 이전 일시정지 시점부터 시작
      _lastElapsedTime = 0;
    }

    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      try {
        value++;
      } catch (e) {
        print('Timer error: $e');
        pauseTimer();
      }
    });

    notifyListeners(); // 상태 변경 알림 추가
  }

  void pauseTimer() {
    if (!_isRunning || _isPaused) return;

    _timer?.cancel();
    _isRunning = false;
    _isPaused = true;
    _lastElapsedTime = value; // 현재 시간 저장
    notifyListeners();
  }

  void resetTimer() {
    if (value == 0 && !_isRunning && !_isPaused) return;

    _timer?.cancel();
    _isRunning = false;
    _isPaused = false;
    _lastElapsedTime = 0;
    value = 0;
    notifyListeners(); // 모든 상태가 변경되므로 알림 추가
  }

  void resumeTimer() {
    if (_isRunning || !_isPaused) return;
    startTimer();
  }

  @override
  void dispose() {
    _timer?.cancel();
    _lastElapsedTime = 0;
    super.dispose();
  }
}
