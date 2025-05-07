//widget_draggable_dst.dart에서 사용하는 시간 형식 관련 코드 파일

class FormatUtils {
  static String formatDistance(double distance) {
    // 1000m 미만일 때 m로 표시
    if (distance < 1000) {
      return '${distance.toStringAsFixed(1)} m';
    }
    // 1000m 이상 100000m 미만일 때 km로 표시 (소수점 1자리)
    else if (distance < 100000) {
      return '${(distance / 1000).toStringAsFixed(1)} km';
    }
    // 100000m 이상일 때 km로 표시 (소수점 없이 정수)
    else {
      return '${(distance / 1000).toInt()} km';
    }
  }

  //산책 시간 표시 형식 붙이기
  static String formatTime(int seconds) {
    //60초 미만일 때 ~초로 표시
    if (seconds < 60) {
      return '$seconds 초';
    }
    // 3600초 미만일 떄 분:초로 표시
    else if (seconds < 3600) {
      final minutes = seconds ~/ 60;
      final remainingSeconds = seconds % 60;
      return '$minutes:${remainingSeconds.toString().padLeft(2, '0')}';
    }
    //3600초 이상일 떄 시:분:초로 표시
    else {
      final hours = seconds ~/ 3600;
      final minutes = (seconds % 3600) ~/ 60;
      final remainingSeconds = seconds % 60;
      return '$hours:${minutes.toString().padLeft(2, '0')}:${remainingSeconds.toString().padLeft(2, '0')}';
    }
  }
}
