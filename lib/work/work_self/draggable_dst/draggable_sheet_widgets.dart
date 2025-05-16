import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:dangq/colors.dart';
import 'package:dangq/work/work_self/draggable_dst/format_utils.dart';

//드로어블 시트 위젯 모음

class DraggableSheetWidgets {
  static Widget dragHandle() {
    return Container(
      height: 3.0,
      width: 30.0,
      decoration: BoxDecoration(
        color: AppColors.workDSTGray,
        borderRadius: BorderRadius.circular(2.0),
      ),
    );
  }

  static Widget topSection({
    required double speed,
    required ValueListenable<int> timerController,
    required double totalDistance,
  }) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        Expanded(
            child: _textBox('시간', 's', speed, timerController, totalDistance)),
        _verticalLine(),
        Expanded(
            child:
                _textBox('이동거리', 'm', speed, timerController, totalDistance)),
        _verticalLine(),
        Expanded(
            child:
                _textBox('속력', 'km/h', speed, timerController, totalDistance)),
      ],
    );
  }

  static Widget _textBox(String label, String type, double speed,
      ValueListenable<int> timerController, double totalDistance) {
    return Column(
      children: [
        Text(label, style: const TextStyle(color: Colors.black)),
        const SizedBox(height: 7),
        ValueListenableBuilder<int>(
          valueListenable: timerController,
          builder: (context, time, child) {
            String displayValue = '';
            switch (type) {
              case 'km/h':
                displayValue = speed.toStringAsFixed(1);
                break;
              case 's':
                displayValue = FormatUtils.formatTime(time);
                break;
              case 'm':
                displayValue = totalDistance.toStringAsFixed(1) + 'm';
                break;
            }
            return Text(displayValue,
                style: const TextStyle(color: Colors.black));
          },
        ),
      ],
    );
  }

  // 세로 줄을 그리는 위젯
  static Widget _verticalLine() {
    return Container(
      width: 1,
      height: 90,
      color: AppColors.lightgreen,
    );
  }

  // 가로 줄을 그리는 위젯
  static Widget horizontalLine() {
    return Container(
      height: 2.0,
      width: 465.0,
      color: AppColors.lightgreen,
    );
  }

  //드로어블 시트의 하단 위젯
  static Widget bottomSection({
    required bool isRunning,
    required VoidCallback onStartPressed,
    required VoidCallback onStopPressed,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // 시작 버튼
          AnimatedOpacity(
            duration: const Duration(milliseconds: 200),
            opacity: isRunning ? 0.5 : 1.0,
            child: ElevatedButton(
              onPressed: isRunning ? null : onStartPressed,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF79B883),
                foregroundColor: Colors.white,
                elevation: 0,
                padding:
                    const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.play_arrow_rounded,
                    size: 20,
                    color: isRunning ? Colors.grey[400] : Colors.white,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    '시작',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: isRunning ? Colors.grey[400] : Colors.white,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(width: 24),
          // 중지 버튼
          ElevatedButton(
            onPressed: isRunning ? onStopPressed : null,
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFFF6B6B),
              foregroundColor: Colors.white,
              elevation: 0,
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.stop_rounded,
                  size: 20,
                  color: isRunning ? Colors.white : Colors.grey[400],
                ),
                const SizedBox(width: 6),
                Text(
                  '중지',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: isRunning ? Colors.white : Colors.grey[400],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
