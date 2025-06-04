const express = require('express');
const router = express.Router();
const axios = require('axios');
require('dotenv').config(); // ✅ 이 줄 반드시 포함

const TMAP_APP_KEY = process.env.TMAP_APP_KEY;


// 경로 요청 라우터
router.post('/getPath', async (req, res) => {
  try {
    const { start, end, stopovers } = req.body;

    if (!start || !end) {
      return res.status(400).json({ message: 'start와 end가 필요합니다.' });
    }

    if (stopovers && stopovers.length > 0) {
      const allPaths = await calculateRouteWithStopovers(start, end, stopovers);
      return res.json({ path: allPaths, routeType: 'multi-segment' });
    } else {
      const path = await calculateDirectRoute(start, end);
      return res.json({ path: path, routeType: 'direct' });
    }
  } catch (error) {
    console.error('경로 요청 실패:', error.response?.data || error.message);
    return res.status(500).json({
      message: '서버 오류로 인해 경로를 계산할 수 없습니다.',
      error: error.response?.data || error.message,
    });
  }
});

// 직접 경로 계산 (경유지 없음)
async function calculateDirectRoute(start, end) {
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
    searchOption: '0'
  };

  const headers = {
    'appKey': TMAP_APP_KEY,
    'Content-Type': 'application/json',
  };

  // 디버깅용 로그
  console.log('TMAP_APP_KEY:', TMAP_APP_KEY);
  console.log('요청 Headers:', headers);
  console.log('요청 Body:', JSON.stringify(data, null, 2));

  const response = await axios.post(url, data, { headers });

  if (!response.data || !response.data.features) {
    throw new Error('유효하지 않은 API 응답');
  }

  const path = [];

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

  return cleanPath(path);
}

// 경유지 포함 경로 계산
async function calculateRouteWithStopovers(start, end, stopovers) {
  const waypoints = [start, ...stopovers, end];
  const allPaths = [];

  for (let i = 0; i < waypoints.length - 1; i++) {
    const segmentStart = waypoints[i];
    const segmentEnd = waypoints[i + 1];

    try {
      const segmentPath = await calculateDirectRoute(segmentStart, segmentEnd);

      if (i > 0 && segmentPath.length > 0) {
        segmentPath.shift(); // 중복 제거
      }

      allPaths.push(...segmentPath);
    } catch (error) {
      console.error(`구간 ${i}-${i + 1} 경로 계산 실패:`, error.message);

      if (i === 0 || allPaths.length === 0) {
        allPaths.push({ lat: segmentStart.lat, lng: segmentStart.lng });
      }
      allPaths.push({ lat: segmentEnd.lat, lng: segmentEnd.lng });
    }
  }

  return cleanPath(allPaths);
}

// 경로 중복 제거 및 정리
function cleanPath(path) {
  if (!path || path.length === 0) return [];

  const cleanedPath = [];
  const tolerance = 0.00001;

  for (let i = 0; i < path.length; i++) {
    const point = path[i];

    if (!point || typeof point.lat !== 'number' || typeof point.lng !== 'number') continue;

    if (cleanedPath.length === 0) {
      cleanedPath.push(point);
    } else {
      const lastPoint = cleanedPath[cleanedPath.length - 1];
      const distance = calculateDistance(point, lastPoint);

      if (distance > tolerance) {
        cleanedPath.push(point);
      }
    }
  }

  return cleanedPath;
}

// 거리 계산 (단순 유클리드)
function calculateDistance(point1, point2) {
  const dlat = point1.lat - point2.lat;
  const dlng = point1.lng - point2.lng;
  return Math.sqrt(dlat * dlat + dlng * dlng);
}

module.exports = router;
