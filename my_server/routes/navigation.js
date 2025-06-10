const express = require('express');
const router = express.Router();
const axios = require('axios');
const db = require('../config/database');

const TMAP_APP_KEY = process.env.TMAP_APP_KEY;

function getDistanceMeters(lat1, lng1, lat2, lng2) {
  const R = 6371000;
  const dLat = (lat2 - lat1) * Math.PI / 180;
  const dLng = (lng2 - lng1) * Math.PI / 180;
  const a = Math.sin(dLat / 2) ** 2 +
            Math.cos(lat1 * Math.PI / 180) *
            Math.cos(lat2 * Math.PI / 180) *
            Math.sin(dLng / 2) ** 2;
  const c = 2 * Math.atan2(Math.sqrt(a), Math.sqrt(1 - a));
  return R * c;
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

  return clusters.filter(c => c.markers.length >= minClusterSize).map(c => {
    const latSum = c.markers.reduce((sum, m) => sum + m.latitude, 0);
    const lngSum = c.markers.reduce((sum, m) => sum + m.longitude, 0);
    const count = c.markers.length;
    return {
      lat: latSum / count,
      lng: lngSum / count,
      density: count
    };
  });
}

function selectGoodWaypoints(start, end, goodMarkers, excludeWaypoints = []) {
  const MIN_DISTANCE = 100; // m, excludeWaypoints 제외 기준
  const MAX_CLUSTER_RADIUS = 50; // m, 군집 반경
  const MIN_CLUSTER_SIZE = 3;     // 최소 마커 수
  const CLUSTER_DUPLICATE_THRESHOLD = 100; // m, 군집 간 중복 거리
  const DISTANCE_MULTIPLIER = 1.5;

  function getDistance(lat1, lon1, lat2, lon2) {
    const R = 6371e3;
    const φ1 = lat1 * Math.PI / 180;
    const φ2 = lat2 * Math.PI / 180;
    const Δφ = (lat2 - lat1) * Math.PI / 180;
    const Δλ = (lon2 - lon1) * Math.PI / 180;
    const a = Math.sin(Δφ / 2) ** 2 +
              Math.cos(φ1) * Math.cos(φ2) *
              Math.sin(Δλ / 2) ** 2;
    const c = 2 * Math.atan2(Math.sqrt(a), Math.sqrt(1 - a));
    return R * c;
  }

  function clusterMarkers(markers, radius = MAX_CLUSTER_RADIUS, minSize = MIN_CLUSTER_SIZE) {
    const clusters = [];

    markers.forEach(marker => {
      let added = false;
      for (const cluster of clusters) {
        for (const existing of cluster.markers) {
          const d = getDistance(marker.latitude, marker.longitude, existing.latitude, existing.longitude);
          if (d < radius) {
            cluster.markers.push(marker);
            added = true;
            break;
          }
        }
        if (added) break;
      }

      if (!added) {
        clusters.push({ markers: [marker] });
      }
    });

    return clusters
      .filter(c => c.markers.length >= minSize)
      .map(c => {
        const latSum = c.markers.reduce((sum, m) => sum + m.latitude, 0);
        const lngSum = c.markers.reduce((sum, m) => sum + m.longitude, 0);
        const center = {
          lat: latSum / c.markers.length,
          lng: lngSum / c.markers.length,
        };
        return {
          ...center,
          density: c.markers.length,
        };
      });
  }

  // 1. 군집화
  const clusters = clusterMarkers(goodMarkers);
  console.log('🔍 군집화된 good 마커 수:', clusters.length);

  // 2. 출발지–도착지 직선 거리 기준
  const baseDist = getDistance(start.lat, start.lng, end.lat, end.lng);
  const maxDist = baseDist * DISTANCE_MULTIPLIER;

  let filteredClusters = clusters.filter(cluster => {
    const distFromStart = getDistance(start.lat, start.lng, cluster.lat, cluster.lng);
    const distFromEnd = getDistance(end.lat, end.lng, cluster.lat, cluster.lng);
    const closeToStartOrEnd = Math.min(distFromStart, distFromEnd) <= maxDist;

    const tooCloseToExcluded = excludeWaypoints.some(ex =>
      getDistance(cluster.lat, cluster.lng, ex.latitude, ex.longitude) < MIN_DISTANCE
    );

    return closeToStartOrEnd && !tooCloseToExcluded;
  });

  console.log('✅ 필터링된 군집 수 (거리/제외 기준 통과):', filteredClusters.length);

  // 3. 군집 간 중복 제거 (200m 이내인 군집 제거)
  const finalClusters = [];
  for (const cluster of filteredClusters) {
    const tooClose = finalClusters.some(existing =>
      getDistance(cluster.lat, cluster.lng, existing.lat, existing.lng) < CLUSTER_DUPLICATE_THRESHOLD
    );
    if (!tooClose) {
      finalClusters.push(cluster);
    }
  }

  console.log('🧹 중복 제거 후 최종 군집 수:', finalClusters.length);

  // 4. 최대 2개 반환
  return finalClusters.slice(0, 2).map(c => ({ lat: c.lat, lng: c.lng }));
}



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

  axios.post(url, data, { headers })
    .then(response => {
      if (!response.data || !response.data.features) return callback(new Error('유효하지 않은 API 응답'));
      const path = [];
      response.data.features.forEach(feature => {
        if (feature.geometry?.coordinates) {
          if (feature.geometry.type === 'LineString') {
            feature.geometry.coordinates.forEach(coord => path.push({ lat: coord[1], lng: coord[0] }));
          } else if (feature.geometry.type === 'Point') {
            const coord = feature.geometry.coordinates;
            path.push({ lat: coord[1], lng: coord[0] });
          }
        }
      });
      callback(null, path);
    })
    .catch(err => callback(err));
}

function calculateRouteWithGoodWaypoints(start, end, goodMarkers, callback) {
  const goodWaypoints = selectGoodWaypoints(start, end, goodMarkers);
  const waypoints = goodWaypoints.slice(0, 5);

  if (waypoints.length === 0) {
    return calculateDirectRoute(start, end, callback);
  }

  const points = [start, ...waypoints, end];
  const allPaths = [];
  const visited = new Set();
  let index = 0;

  function coordKey(lat, lng) {
    return `${lat.toFixed(6)},${lng.toFixed(6)}`;
  }

  function processSegment() {
    if (index >= points.length - 1) return callback(null, allPaths);

    const segmentStart = points[index];
    const segmentEnd = points[index + 1];
    calculateDirectRoute(segmentStart, segmentEnd, (err, segmentPath) => {
      if (err || !segmentPath || segmentPath.length < 2) {
        allPaths.push(segmentStart, segmentEnd);
      } else {
        segmentPath.forEach(point => {
          const key = coordKey(point.lat, point.lng);
          if (!visited.has(key)) {
            allPaths.push(point);
            visited.add(key);
          }
        });
      }
      index++;
      processSegment();
    });
  }

  processSegment();
}

// ——— 여기서부터 변경된 generateValidWaypoint 함수 ———

function generateValidWaypoint(start, end, goodMarkers, callback) {
  const earthRadius = 6371000;
  const baseDistance = 200;  // 오른쪽으로 200m 기본 이동거리

  function latLngToXY(lat, lng) {
    const x = lng * Math.PI / 180 * earthRadius * Math.cos(lat * Math.PI / 180);
    const y = lat * Math.PI / 180 * earthRadius;
    return { x, y };
  }

  function xyToLatLng(x, y) {
    const lat = (y / earthRadius) * (180 / Math.PI);
    const lng = (x / (earthRadius * Math.cos(lat * Math.PI / 180))) * (180 / Math.PI);
    return { lat, lng };
  }

  const startXY = latLngToXY(start.lat, start.lng);
  const endXY = latLngToXY(end.lat, end.lng);

  const dx = endXY.x - startXY.x;
  const dy = endXY.y - startXY.y;

  // 오른쪽 수직 벡터 (dy, -dx)
  let rightVec = { x: dy, y: -dx };
  const length = Math.sqrt(rightVec.x ** 2 + rightVec.y ** 2);
  rightVec.x /= length;
  rightVec.y /= length;

  // 중간점
  const midX = (startXY.x + endXY.x) / 2;
  const midY = (startXY.y + endXY.y) / 2;

  // 랜덤 편차: -50 ~ +50 미터 범위 내에서 추가
  const randomOffset = (Math.random() - 0.5) * 100;

  // 최종 경유지 좌표 계산
  const waypointX = midX + rightVec.x * (baseDistance + randomOffset);
  const waypointY = midY + rightVec.y * (baseDistance + randomOffset);

  const waypoint = xyToLatLng(waypointX, waypointY);
  console.log('생성된 랜덤 경유지:', waypoint);

  callback(null, waypoint);
}

// ————————————————————————————————

function getPathDistance(path) {
  let total = 0;
  for (let i = 0; i < path.length - 1; i++) {
    total += getDistanceMeters(path[i].lat, path[i].lng,
                               path[i+1].lat, path[i+1].lng);
  }
  return total;
}

function isReasonableLength(baseDist, newDist) {
  return newDist >= baseDist * 0.5 && newDist <= baseDist * 2.5;
}
function isPathGoingBackwards(p1, p2) {
  const lastP1 = p1[p1.length - 1];
  const firstP2 = p2[0];
  const waypointDist = getDistanceMeters(lastP1.lat, lastP1.lng, firstP2.lat, firstP2.lng);
  if (waypointDist > 30) return true;

  const vecP1 = {
    lat: lastP1.lat - p1[p1.length - 2].lat,
    lng: lastP1.lng - p1[p1.length - 2].lng
  };

  const vecP2 = {
    lat: p2[1].lat - firstP2.lat,
    lng: p2[1].lng - firstP2.lng
  };

  const dot = vecP1.lat * vecP2.lat + vecP1.lng * vecP2.lng;
  if (dot < 0) return true;

  return false;
}

function isValidWaypointInPath(path, waypoint) {
  const threshold = 50;

  let minDist = Infinity;
  for (const point of path) {
    const dist = getDistanceMeters(point.lat, point.lng, waypoint.lat, waypoint.lng);
    if (dist < minDist) minDist = dist;
  }

  return minDist <= threshold;
}

function calculateRouteWithValidation(start, end, waypoint, callback) {
  calculateDirectRoute(start, end, (err, basePath) => {
    if (err) return callback(err);
    const baseDist = getPathDistance(basePath);

    if (!waypoint) return callback(null, basePath);

    calculateDirectRoute(start, waypoint, (e1, p1) => {
      calculateDirectRoute(waypoint, end, (e2, p2) => {
        if (e1 || e2 || !p1.length || !p2.length) return callback(null, basePath);

        if (isPathGoingBackwards(p1, p2)) {
          console.warn('경유지 경로가 되돌아감 - 무시');
          return callback(null, basePath);
        }

        const newPath = [...p1, ...p2];
        const newDist = getPathDistance(newPath);

        const passedWaypoint = isValidWaypointInPath(newPath, waypoint);
        const reasonable = isReasonableLength(baseDist, newDist);

        if (!passedWaypoint || !reasonable) {
          return callback(null, newPath);
        }

        callback(null, newPath);
      });
    });
  });
}

router.post('/getPath', (req, res) => {
  const { start, end } = req.body;
  if (!start || !end) return res.status(400).json({ message: 'start와 end가 필요합니다.' });

  db.query('SELECT latitude, longitude FROM markers WHERE marker_type = "good"', (err, goodMarkers) => {
    if (err) return res.status(500).json({ message: 'DB 오류 발생' });

    // 1) goodMarkers 클러스터링 후 우선순위 1위 경유지 1개 선택
    const waypoints = selectGoodWaypoints(start, end, goodMarkers);
    const selectedWaypoint = waypoints.length > 0 ? waypoints[0] : null;

    // 2) 경로 계산 함수에 경유지 전달
    calculateRouteWithValidation(start, end, selectedWaypoint, (err, path) => {
      if (err) return res.status(500).json({ message: '경로 계산 실패' });

      // 정방향에서 선택한 경유지를 같이 반환 (역방향에서 제외할 용도)
      res.json({ path, usedWaypoint: selectedWaypoint });
    });
  });
});


router.post('/getReversePath', (req, res) => {
  const { start, end, excludeWaypoints = [] } = req.body;
  if (!start || !end) return res.status(400).json({ message: 'start와 end가 필요합니다.' });

  db.query('SELECT latitude, longitude FROM markers WHERE marker_type = "good"', (err, goodMarkers) => {
    if (err) return res.status(500).json({ message: 'DB 오류 발생' });

    const goodWaypoints = selectGoodWaypoints(end, start, goodMarkers, excludeWaypoints);

    if (goodWaypoints.length === 0) {
      return calculateRouteWithValidation(end, start, null, (err, finalPath) => {
        if (err) return res.status(500).json({ message: '경로 계산 실패' });
        res.json({ path: finalPath });
      });

    } else if (goodWaypoints.length === 1) {
      generateValidWaypoint(end, start, goodMarkers, (err, randomWaypoint) => {
        if (err || !randomWaypoint) {
          const waypoint = goodWaypoints[0];
          return calculateRouteWithValidation(end, start, waypoint, (err2, finalPath) => {
            if (err2) return res.status(500).json({ message: '경로 계산 실패' });
            res.json({ path: finalPath });
          });
        }

        calculateRouteWithValidation(end, start, randomWaypoint, (err2, finalPath) => {
          if (err2) return res.status(500).json({ message: '경로 계산 실패' });
          res.json({ path: finalPath });
        });
      });

    } else {
      const waypoint = goodWaypoints[1];
      const points = Array.isArray(waypoint)
        ? [end, ...waypoint, start]
        : [end, waypoint, start];

      let allPaths = [];
      let idx = 0;
      const visited = new Set();

      function coordKey(lat, lng) {
        return `${lat.toFixed(6)},${lng.toFixed(6)}`;
      }

      function processSegment() {
        if (idx >= points.length - 1) {
          return res.json({ path: allPaths });
        }

        const segmentStart = points[idx];
        const segmentEnd = points[idx + 1];
        calculateDirectRoute(segmentStart, segmentEnd, (err, segmentPath) => {
          if (err || !segmentPath || segmentPath.length < 2) {
            allPaths.push(segmentStart, segmentEnd);
          } else {
            segmentPath.forEach(point => {
              const key = coordKey(point.lat, point.lng);
              if (!visited.has(key)) {
                allPaths.push(point);
                visited.add(key);
              }
            });
          }
          idx++;
          processSegment();
        });
      }

      processSegment();
    }
  });
});

module.exports = router;