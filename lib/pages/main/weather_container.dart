import 'package:flutter/material.dart';

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

  // 생성자: 모든 날씨 정보를 필수값으로 받음
  const WeatherContainer({
    super.key,
    required this.location,
    required this.temperature,
    required this.dustStatus,
    required this.uvStatus,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          width: double.infinity,
          // 컨테이너 스타일 설정 (하늘색 배경, 둥근 모서리)
          decoration: BoxDecoration(
            color: const Color(0xFFBEE3F8),
            borderRadius: BorderRadius.circular(10),
          ),
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 위치 정보 표시 섹션
              Row(
                children: [
                  const Icon(Icons.location_on, color: Colors.red),
                  const SizedBox(width: 4),
                  Text(
                    location,
                    style: const TextStyle(fontSize: 16),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              // 날씨 상태 표시 섹션
              Row(
                children: [
                  // 온도 표시
                  Text(
                    '$temperature°C',
                    style: const TextStyle(
                      fontSize: 40,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const Spacer(),
                  // 미세먼지 상태 표시
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('미세먼지', style: TextStyle(fontSize: 14)),
                      Text(
                        dustStatus,
                        style: TextStyle(
                          fontSize: 14,
                          // 미세먼지 상태가 '좋음' 또는 '보통'이면 파란색, 그 외는 빨간색
                          color: (dustStatus == '좋음' || dustStatus == '보통')
                              ? Colors.blue
                              : Colors.red,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(width: 24),
                  // 자외선 상태 표시
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('자외선', style: TextStyle(fontSize: 14)),
                      Text(
                        uvStatus,
                        style: TextStyle(
                          fontSize: 14,
                          // 자외선 상태가 '좋음' 또는 '보통'이면 파란색, 그 외는 빨간색
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
    );
  }
}
