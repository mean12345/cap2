const express = require('express');
const router = express.Router();
const axios = require('axios');
const db = require('../config/database');

const TMAP_APP_KEY = process.env.TMAP_APP_KEY;

// 위도/경도 기준 약 100m 거리 계산용 (Haversine)
function getDistanceMeters(lat1, lng1, lat2, lng2) {
  const R = 6371000; // 지구 반지름 (m)
  const dLat = (lat2 - lat1) * Math.PI / 180;
  const dLng = (lng2 - lng1) * Math.PI / 180;
  const a =
    Math.sin(dLat / 2) * Math.sin(dLat / 2) +
    Math.cos(lat1 * Math.PI / 180) *
      Math.cos(lat2 * Math.PI / 180) *
      Math.sin(dLng / 2) *
      Math.sin(dLng / 2);
  const c = 2 * Math.atan2(Math.sqrt(a), Math.sqrt(1 - a));
  return R * c;
}


function selectGoodWaypoints(start, end, goodMarkers) {
  let clusteredPoints = clusterMarkers(goodMarkers, 50, 3);

  const maxDistMeters = getDistanceMeters(start.lat, start.lng, end.lat, end.lng);

  // start~end 경로 근처 필터링
  clusteredPoints = clusteredPoints.filter(point => {
    const distToStart = getDistanceMeters(start.lat, start.lng, point.lat, point.lng);
    const distToEnd = getDistanceMeters(end.lat, end.lng, point.lat, point.lng);
    return (distToStart + distToEnd) <= maxDistMeters * 1.5;
  });

  // 밀집도 내림차순 정렬 (많이 모인 곳 우선)
  clusteredPoints.sort((a, b) => b.density - a.density);

  console.log(`초기 클러스터 중심 경유지 수(정렬됨): ${clusteredPoints.length}`);

  // 1순위 경유지 기준 500m 내 중복 제거
  const selectedPoints = [];
  const exclusionRadius = 500; // 500m 반경

  clusteredPoints.forEach(point => {
    // 이미 선택된 경유지 중에 이 point와 500m 이내인 게 있으면 제외
    const isExcluded = selectedPoints.some(selected => {
      return getDistanceMeters(selected.lat, selected.lng, point.lat, point.lng) <= exclusionRadius;
    });

    if (!isExcluded) {
      selectedPoints.push(point);
    }
  });

  console.log(`500m 이내 중복 제거 후 경유지 수: ${selectedPoints.length}`);

  return selectedPoints;
}


// 경로 계산 함수
function calculateRouteWithGoodWaypoints(start, end, goodMarkers, callback) {
  const goodWaypoints = selectGoodWaypoints(start, end, goodMarkers);
  let waypoints = [...goodWaypoints];

  if (waypoints.length > 5) {
    waypoints.splice(5);
    console.log('경유지가 5개를 초과하여 잘랐습니다.');
  }

  if (waypoints.length === 0) {
    console.log('경유지가 없어 직선 경로 요청');
    return calculateDirectRoute(start, end, callback);
  }

  const points = [start, ...waypoints, end];
  let allPaths = [];
  const visited = new Set(); // 방문한 좌표 저장용
  let index = 0;

  function coordKey(lat, lng) {
    return `${lat.toFixed(6)},${lng.toFixed(6)}`;
  }

  function processSegment() {
    if (index >= points.length - 1) {
      console.log('모든 경로 계산 완료');
      return callback(null, allPaths);
    }

    const segmentStart = points[index];
    const segmentEnd = points[index + 1];
    console.log(`구간 ${index} -> ${index + 1} 경로 계산 중...`);

    calculateDirectRoute(segmentStart, segmentEnd, (err, segmentPath) => {
      if (err) {
        console.error(`구간 ${index}~${index + 1} 실패:`, err.message);
        // 실패 시 구간 시작/끝 좌표만 추가
        allPaths.push({ lat: segmentStart.lat, lng: segmentStart.lng });
        allPaths.push({ lat: segmentEnd.lat, lng: segmentEnd.lng });
      } else {
        // 중복 좌표 제거 후 추가
        segmentPath.forEach((point) => {
          const key = coordKey(point.lat, point.lng);
          if (!visited.has(key)) {
            allPaths.push(point);
            visited.add(key);
          }
        });
        console.log(`구간 ${index} -> ${index + 1} 경로 점 개수: ${segmentPath.length}`);
      }

      index++;
      processSegment();
    });
  }

  processSegment();
}
function clusterMarkers(markers, radiusMeters = 50, minClusterSize = 3) {
  const clusters = [];

  markers.forEach(marker => {
    let addedToCluster = false;
    for (const cluster of clusters) {
      for (const existing of cluster.markers) {
        const dist = getDistanceMeters(existing.latitude, existing.longitude, marker.latitude, marker.longitude);
        if (dist < radiusMeters) {
          cluster.markers.push(marker);
          addedToCluster = true;
          break;
        }
      }
      if (addedToCluster) break;
    }

    if (!addedToCluster) {
      clusters.push({ markers: [marker] });
    }
  });

  // 중심 좌표와 밀집도(마커 개수) 반환
  const centroids = clusters
    .filter(cluster => cluster.markers.length >= minClusterSize)
    .map(cluster => {
      const latSum = cluster.markers.reduce((sum, m) => sum + m.latitude, 0);
      const lngSum = cluster.markers.reduce((sum, m) => sum + m.longitude, 0);
      const count = cluster.markers.length;
      return {
        lat: latSum / count,
        lng: lngSum / count,
        density: count // 밀집도
      };
    });

  console.log(`클러스터 개수: ${centroids.length}`);
  return centroids;
}

// TMAP 도보 경로 API 호출
function calculateDirectRoute(start, end, callback) {
  const url = 'https://apis.openapi.sk.com/tmap/routes/pedestrian';
  const data = {
    startX: String(start.lng),
    startY: String(start.lat),
    endX: String(end.lng),
    endY: String(end.lat),
    startName: '출발지',
    endName: '도착지',
    reqCoordType: 'WGS84GEO',
    resCoordType: 'WGS84GEO',
    searchOption: '10'
  };
  const headers = {
    'appKey': TMAP_APP_KEY,
    'Content-Type': 'application/json'
  };

  console.log('TMAP API 요청:', data);

  axios.post(url, data, { headers })
    .then(response => {
      if (!response.data || !response.data.features) {
        console.error('TMAP 응답 비정상:', response.data);
        return callback(new Error('유효하지 않은 API 응답'));
      }
      let path = [];
      response.data.features.forEach(feature => {
        if (feature.geometry?.coordinates) {
          if (feature.geometry.type === 'LineString') {
            feature.geometry.coordinates.forEach(coord => {
              path.push({ lat: coord[1], lng: coord[0] });
            });
          } else if (feature.geometry.type === 'Point') {
            const coord = feature.geometry.coordinates;
            path.push({ lat: coord[1], lng: coord[0] });
          }
        }
      });
      console.log('TMAP 경로 길이:', path.length);
      callback(null, path);
    })
    .catch(err => {
      console.error('TMAP API 오류:', err.message);
      callback(err);
    });
}

// POST 요청 핸들러
router.post('/getPath', (req, res) => {
  const { start, end } = req.body;
  console.log('받은 요청:', start, end);

  if (!start || !end) {
    return res.status(400).json({ message: 'start와 end가 필요합니다.' });
  }

  db.query('SELECT latitude, longitude FROM markers WHERE marker_type = "good"', (err, goodMarkers) => {
    if (err) {
      console.error('DB 조회 오류:', err);
      return res.status(500).json({ message: 'DB 오류 발생' });
    }

    console.log(`조회된 good 마커 수: ${goodMarkers.length}`);

    calculateRouteWithGoodWaypoints(start, end, goodMarkers, (err, path) => {
      if (err) {
        console.error('경로 계산 실패:', err);
        return res.status(500).json({ message: '경로 계산 실패' });
      }
      console.log('최종 경로 반환');
      res.json({ path });
    });
  });
});
// 역방향 경로 계산용 POST 라우터
router.post('/getReversePath', (req, res) => {
  const { start, end } = req.body;
  console.log('받은 역방향 요청:', start, end);

  if (!start || !end) {
    return res.status(400).json({ message: 'start와 end가 필요합니다.' });
  }

  // 여기서는 경유지 없이 단순히 end->start 순서로 요청
  calculateDirectRoute(end, start, (err, path) => {
    if (err) {
      console.error('역방향 경로 계산 실패:', err);
      return res.status(500).json({ message: '경로 계산 실패' });
    }
    console.log('최종 역방향 경로 반환');
    res.json({ path });
  });
});

module.exports = router;