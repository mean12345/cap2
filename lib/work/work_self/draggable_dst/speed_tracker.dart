import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';

//GPS 위치 변화를 기반으로 사용자의 실시간 속도를 계산하고 업데이트

class SpeedTracker {
  final Function(double) onSpeedUpdate;
  double currentSpeed = 0.0;
  Position? lastPosition;
  DateTime? lastUpdateTime;
  bool isRecording = false;

  SpeedTracker({required this.onSpeedUpdate});

  void startTracking() {
    isRecording = true;
    lastPosition = null;
    lastUpdateTime = null;
    currentSpeed = 0.0;
  }

  void updateSpeed(Position newPosition) {
    if (!isRecording) return;

    final now = DateTime.now();
    if (lastPosition != null && lastUpdateTime != null) {
      final distance = Geolocator.distanceBetween(
        lastPosition!.latitude,
        lastPosition!.longitude,
        newPosition.latitude,
        newPosition.longitude,
      );

      final timeDiff = now.difference(lastUpdateTime!).inSeconds;
      if (timeDiff > 0) {
        currentSpeed = (distance / timeDiff) * 3.6; // m/s to km/h
        onSpeedUpdate(currentSpeed);
      }
    }

    lastPosition = newPosition;
    lastUpdateTime = now;
  }

  void stopTracking() {
    isRecording = false;
    currentSpeed = 0.0;
    onSpeedUpdate(currentSpeed);
  }

  void reset() {
    currentSpeed = 0.0;
    lastPosition = null;
    lastUpdateTime = null;
    onSpeedUpdate(currentSpeed);
  }
}
