// walking_tracking_page.dart
import 'package:flutter/material.dart';
import 'package:flutter_naver_map/flutter_naver_map.dart';
import 'package:geolocator/geolocator.dart';
import 'dart:async';

class WalkingTrackingPage extends StatefulWidget {
  final List<NLatLng> routePath;
  final List<NLatLng> stopovers;

  const WalkingTrackingPage({
    super.key,
    required this.routePath,
    required this.stopovers,
  });

  @override
  State<WalkingTrackingPage> createState() => _WalkingTrackingPageState();
}

class _WalkingTrackingPageState extends State<WalkingTrackingPage> {
  NaverMapController? _mapController;
  StreamSubscription<Position>? _positionStream;
  
  // 추적 상태
  bool _isTracking = false;
  DateTime? _startTime;
  double _totalDistance = 0.0;
  double _currentSpeed = 0.0;
  Duration _elapsedTime = Duration.zero;
  Timer? _timer;
  
  // 경로 관련
  List<NLatLng> _remainingPath = [];
  List<NLatLng> _completedPath = [];
  NLatLng? _currentPosition;
  
  // 마커 및 오버레이
  NMarker? _currentPositionMarker;
  NPolylineOverlay? _remainingRoutePolyline;
  NPolylineOverlay? _completedRoutePolyline;

  @override
  void initState() {
    super.initState();
    _remainingPath = List.from(widget.routePath);
    _setupInitialMap();
  }

  @override
  void dispose() {
    _stopTracking();
    super.dispose();
  }

  Future<void> _setupInitialMap() async {
    // 초기 지도 설정
    await Future.delayed(const Duration(milliseconds: 500));
    if (_mapController != null) {
      await _displayInitialRoute();
    }
  }

  Future<void> _displayInitialRoute() async {
    if (_mapController == null || widget.routePath.isEmpty) return;

    // 전체 경로 표시
    final routePolyline = NPolylineOverlay(
      id: 'initial_route',
      coords: widget.routePath,
      color: Colors.blue,
      width: 5,
    );

    await _mapController!.addOverlay(routePolyline);
    setState(() {
      _remainingRoutePolyline = routePolyline;
    });

    // 경유지 마커들 추가
    for (int i = 0; i < widget.stopovers.length; i++) {
      final marker = NMarker(
        id: 'stopover_$i',
        position: widget.stopovers[i],
        iconTintColor: Colors.yellow,
        caption: NOverlayCaption(text: '경유지 ${i + 1}'),
      );
      await _mapController!.addOverlay(marker);
    }

    // 시작점과 끝점 마커
    if (widget.routePath.isNotEmpty) {
      final startMarker = NMarker(
        id: 'start',
        position: widget.routePath.first,
        iconTintColor: Colors.blue,
        caption: NOverlayCaption(text: '출발지'),
      );
      
      final endMarker = NMarker(
        id: 'end',
        position: widget.routePath.last,
        iconTintColor: Colors.green,
        caption: NOverlayCaption(text: '도착지'),
      );

      await _mapController!.addOverlay(startMarker);
      await _mapController!.addOverlay(endMarker);
    }
  }

  void _startTracking() async {
    if (_isTracking) return;

    final permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      await Geolocator.requestPermission();
    }

    setState(() {
      _isTracking = true;
      _startTime = DateTime.now();
      _elapsedTime = Duration.zero;
    });

    // 위치 추적 시작
    _positionStream = Geolocator.getPositionStream(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: 5, // 5미터마다 업데이트
      ),
    ).listen(_onPositionUpdate);

    // 타이머 시작
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_startTime != null) {
        setState(() {
          _elapsedTime = DateTime.now().difference(_startTime!);
        });
      }
    });
  }

  void _stopTracking() {
    _positionStream?.cancel();
    _timer?.cancel();
    setState(() {
      _isTracking = false;
    });
  }

  void _pauseTracking() {
    if (!_isTracking) return;
    
    _positionStream?.pause();
    _timer?.cancel();
    
    setState(() {
      _isTracking = false;
    });
  }

  void _resumeTracking() {
    if (_isTracking || _startTime == null) return;
    
    setState(() {
      _isTracking = true;
    });

    // 위치 추적 재시작
    _positionStream?.resume();
    
    // 타이머 재시작
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_startTime != null) {
        setState(() {
          _elapsedTime = DateTime.now().difference(_startTime!);
        });
      }
    });
  }

  void _resetTracking() {
    _stopTracking();
    
    setState(() {
      _totalDistance = 0.0;
      _currentSpeed = 0.0;
      _elapsedTime = Duration.zero;
      _startTime = null;
      _remainingPath = List.from(widget.routePath);
      _completedPath.clear();
      _currentPosition = null;
    });
    
    // 지도 초기화
    _setupInitialMap();
  }

  void _onPositionUpdate(Position position) async {
    final newPosition = NLatLng(position.latitude, position.longitude);
    
    // 현재 위치 업데이트
    if (_currentPosition != null) {
      final distance = Geolocator.distanceBetween(
        _currentPosition!.latitude,
        _currentPosition!.longitude,
        newPosition.latitude,
        newPosition.longitude,
      );
      _totalDistance += distance;
    }

    // 속력 계산 (m/s에서 km/h로 변환)
    _currentSpeed = position.speed * 3.6;

    setState(() {
      _currentPosition = newPosition;
    });

    // 지나간 경로 업데이트
    _updateRouteProgress(newPosition);
    
    // 현재 위치 마커 업데이트
    await _updateCurrentPositionMarker(newPosition);
    
    // 카메라를 현재 위치로 이동
    if (_mapController != null) {
      await _mapController!.updateCamera(
        NCameraUpdate.withParams(
          target: newPosition,
          zoom: 16,
        ),
      );
    }
  }

  void _updateRouteProgress(NLatLng currentPos) {
    if (_remainingPath.isEmpty) return;

    const double threshold = 20.0; // 20미터 임계값

    // 현재 위치에서 가장 가까운 경로 지점 찾기
    int closestIndex = -1;
    double minDistance = double.infinity;

    for (int i = 0; i < _remainingPath.length; i++) {
      final distance = Geolocator.distanceBetween(
        currentPos.latitude,
        currentPos.longitude,
        _remainingPath[i].latitude,
        _remainingPath[i].longitude,
      );

      if (distance < minDistance) {
        minDistance = distance;
        closestIndex = i;
      }
    }

    // 임계값 내에 있으면 해당 지점까지의 경로를 완료된 것으로 처리
    if (closestIndex != -1 && minDistance <= threshold) {
      final completedSegment = _remainingPath.take(closestIndex + 1).toList();
      _completedPath.addAll(completedSegment);
      _remainingPath.removeRange(0, closestIndex + 1);
      
      // 경로 오버레이 업데이트
      _updateRouteOverlays();
    }
  }

  Future<void> _updateRouteOverlays() async {
    if (_mapController == null) return;

    // 기존 경로 오버레이 삭제
    if (_remainingRoutePolyline != null) {
      await _mapController!.deleteOverlay(_remainingRoutePolyline!.info);
    }
    if (_completedRoutePolyline != null) {
      await _mapController!.deleteOverlay(_completedRoutePolyline!.info);
    }

    // 완료된 경로 (회색)
    if (_completedPath.isNotEmpty) {
      final completedPolyline = NPolylineOverlay(
        id: 'completed_route',
        coords: _completedPath,
        color: Colors.grey,
        width: 5,
      );
      await _mapController!.addOverlay(completedPolyline);
      setState(() {
        _completedRoutePolyline = completedPolyline;
      });
    }

    // 남은 경로 (파란색)
    if (_remainingPath.isNotEmpty) {
      final remainingPolyline = NPolylineOverlay(
        id: 'remaining_route',
        coords: _remainingPath,
        color: Colors.blue,
        width: 5,
      );
      await _mapController!.addOverlay(remainingPolyline);
      setState(() {
        _remainingRoutePolyline = remainingPolyline;
      });
    }
  }

  Future<void> _updateCurrentPositionMarker(NLatLng position) async {
    if (_mapController == null) return;

    // 기존 마커 삭제
    if (_currentPositionMarker != null) {
      await _mapController!.deleteOverlay(_currentPositionMarker!.info);
    }

    // 새 현재 위치 마커 생성
    final marker = NMarker(
      id: 'current_position',
      position: position,
      iconTintColor: Colors.red,
      caption: NOverlayCaption(text: '현재 위치'),
    );

    await _mapController!.addOverlay(marker);
    setState(() {
      _currentPositionMarker = marker;
    });
  }

  void _showTrackingResults() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('산책 완료!'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('총 시간: ${_formatDuration(_elapsedTime)}'),
              Text('총 거리: ${_formatDistance(_totalDistance)}'),
              Text('평균 속도: ${(_totalDistance / _elapsedTime.inSeconds * 3.6).toStringAsFixed(1)} km/h'),
              const SizedBox(height: 10),
              if (_remainingPath.isEmpty)
                const Text('🎉 경로를 모두 완주했습니다!', 
                    style: TextStyle(color: Colors.green, fontWeight: FontWeight.bold))
              else
                Text('남은 경로: ${_remainingPath.length}개 지점', 
                    style: const TextStyle(color: Colors.orange)),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('확인'),
            ),
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
                Navigator.of(context).pop(); // 메인 화면으로 돌아가기
              },
              child: const Text('완료'),
            ),
          ],
        );
      },
    );
  }

  String _formatDuration(Duration duration) {
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    final hours = twoDigits(duration.inHours);
    final minutes = twoDigits(duration.inMinutes.remainder(60));
    final seconds = twoDigits(duration.inSeconds.remainder(60));
    return '$hours:$minutes:$seconds';
  }

  String _formatDistance(double meters) {
    if (meters < 1000) {
      return '${meters.toStringAsFixed(0)}m';
    } else {
      return '${(meters / 1000).toStringAsFixed(2)}km';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('산책 추적'),
        backgroundColor: Colors.green,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _resetTracking,
            tooltip: '리셋',
          ),
          IconButton(
            icon: Icon(_isTracking ? Icons.pause : Icons.play_arrow),
            onPressed: _isTracking ? _pauseTracking : (_startTime == null ? _startTracking : _resumeTracking),
            tooltip: _isTracking ? '일시정지' : (_startTime == null ? '추적 시작' : '추적 재시작'),
          ),
          if (_startTime != null)
            IconButton(
              icon: const Icon(Icons.stop),
              onPressed: () {
                _stopTracking();
                _showTrackingResults();
              },
              tooltip: '추적 완료',
            ),
        ],
      ),
      body: Stack(
        children: [
          NaverMap(
            onMapReady: (controller) {
              _mapController = controller;
              _setupInitialMap();
            },
            options: NaverMapViewOptions(
              locationButtonEnable: true,
              initialCameraPosition: NCameraPosition(
                target: widget.routePath.isNotEmpty 
                    ? widget.routePath.first 
                    : const NLatLng(35.853488, 128.488708),
                zoom: 16,
              ),
            ),
          ),

          // 상단 통계 패널
          Positioned(
            top: 10,
            left: 10,
            right: 10,
            child: Card(
              color: Colors.white.withOpacity(0.95),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: [
                        Column(
                          children: [
                            const Icon(Icons.timer, color: Colors.blue),
                            const SizedBox(height: 4),
                            Text(
                              _formatDuration(_elapsedTime),
                              style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const Text('시간', style: TextStyle(fontSize: 12)),
                          ],
                        ),
                        Column(
                          children: [
                            const Icon(Icons.straighten, color: Colors.green),
                            const SizedBox(height: 4),
                            Text(
                              _formatDistance(_totalDistance),
                              style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const Text('거리', style: TextStyle(fontSize: 12)),
                          ],
                        ),
                        Column(
                          children: [
                            const Icon(Icons.speed, color: Colors.orange),
                            const SizedBox(height: 4),
                            Text(
                              '${_currentSpeed.toStringAsFixed(1)}',
                              style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const Text('km/h', style: TextStyle(fontSize: 12)),
                          ],
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    // 진행률 표시
                    LinearProgressIndicator(
                      value: widget.routePath.isEmpty ? 0 : 
                          (_completedPath.length / widget.routePath.length).clamp(0.0, 1.0),
                      backgroundColor: Colors.grey[300],
                      valueColor: const AlwaysStoppedAnimation<Color>(Colors.green),
                    ),
                    const SizedBox(height: 8),
                    if (_remainingPath.isNotEmpty)
                      Text(
                        '진행률: ${((_completedPath.length / widget.routePath.length) * 100).toStringAsFixed(1)}% (${_remainingPath.length}개 지점 남음)',
                        style: const TextStyle(fontSize: 12, color: Colors.grey),
                      )
                    else if (_completedPath.isNotEmpty)
                      const Text(
                        '🎉 경로 완주! 축하합니다!',
                        style: TextStyle(fontSize: 12, color: Colors.green, fontWeight: FontWeight.bold),
                      ),
                  ],
                ),
              ),
            ),
          ),

          // 하단 제어 버튼
          Positioned(
            bottom: 20,
            left: 20,
            right: 20,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // 메인 추적 버튼
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _isTracking ? Colors.orange : Colors.green,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 15),
                    ),
                    onPressed: _isTracking ? _pauseTracking : (_startTime == null ? _startTracking : _resumeTracking),
                    icon: Icon(_isTracking ? Icons.pause : Icons.play_arrow),
                    label: Text(
                      _isTracking ? '일시정지' : (_startTime == null ? '추적 시작' : '추적 재시작'),
                      style: const TextStyle(fontSize: 16),
                    ),
                  ),
                ),
                
                // 부가 버튼들
                if (_startTime != null) ...[
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(
                        child: ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.red,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 12),
                          ),
                          onPressed: () {
                            _stopTracking();
                            _showTrackingResults();
                          },
                          icon: const Icon(Icons.stop),
                          label: const Text('완료'),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.grey,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 12),
                          ),
                          onPressed: _resetTracking,
                          icon: const Icon(Icons.refresh),
                          label: const Text('리셋'),
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),

          // 상태 표시 (추적 중일 때)
          if (_isTracking)
            Positioned(
              top: 120,
              right: 10,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.red,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 8,
                      height: 8,
                      decoration: const BoxDecoration(
                        color: Colors.white,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 6),
                    const Text(
                      '추적 중',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}