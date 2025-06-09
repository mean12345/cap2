import 'package:flutter/material.dart';
import 'package:dangq/colors.dart';

/// 날씨 정보를 표시하는 위젯
/// 위치, 온도, 미세먼지, 자외선 상태를 포함
class WeatherContainer extends StatelessWidget {
  // 위치 정보 문자열
  final String location;
  // 온도 정보 문자열
  final String temperature;
  // 미세먼지 상태 문자열 ('좋음', '보통', '나쁨', '매우나쁨')
  final String dustStatus;
  // 자외선 상태 문자열 ('좋음', '보통', '높음', '매우높음')
  final String uvStatus;
  // 투명도 매개변수 추가
  final double opacity;

  // 생성자: 모든 날씨 정보를 필수값으로 받음
  const WeatherContainer({
    super.key,
    required this.location,
    required this.temperature,
    required this.dustStatus,
    required this.uvStatus,
    this.opacity = 0.0, // 기본값 1.0 (완전 불투명)
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      width: double.infinity,
      decoration: BoxDecoration(
        color: Color.fromARGB(
          (opacity * 255).round(),
          255,
          255,
          255,
        ),
        borderRadius: BorderRadius.circular(15),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 위치 정보 표시 섹션
          Row(
            children: [
              const SizedBox(width: 18),
              const Icon(Icons.location_on, color: AppColors.olivegreen),
              const SizedBox(width: 3),
              Text(
                location,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                  color: AppColors.textPrimary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          // 날씨 상태 표시 섹션
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              // 온도 표시
              Expanded(
                flex: 2,
                child: Row(
                  children: [
                    const SizedBox(width: 24),
                    Text(
                      '$temperature°C',
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textPrimary,
                      ),
                    ),
                  ],
                ),
              ),
              // 미세먼지와 자외선 상태를 담는 Row
              Expanded(
                flex: 2,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    // 미세먼지 상태 표시
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const Text('미세먼지',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w500,
                                )),
                            const SizedBox(width: 8),
                            Text(
                              dustStatus,
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w500,
                                color:
                                    (dustStatus == '좋음' || dustStatus == '보통')
                                        ? Colors.blue
                                        : Colors.red,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            const Text('자외선',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w500,
                                )),
                            const SizedBox(width: 8),
                            Text(
                              uvStatus,
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w500,
                                color: (uvStatus == '좋음' || uvStatus == '보통')
                                    ? Colors.blue
                                    : Colors.red,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
