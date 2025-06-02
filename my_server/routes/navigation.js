const express = require('express');
const router = express.Router();
const axios = require('axios');
require('dotenv').config();

const TMAP_APP_KEY = process.env.TMAP_APP_KEY;

// 경로 요청 라우터 (도보 경로)
router.post('/getPath', async (req, res) => {
  try {
    const { start, end, stopovers } = req.body;

    if (!start || !end) {
      return res.status(400).json({ message: 'start와 end가 필요합니다.' });
    }

    // 경유지가 있는 경우와 없는 경우를 분리하여 처리
    if (stopovers && stopovers.length > 0) {
      // 경유지가 있는 경우: 단계별로 경로를 계산
      const allPaths = await calculateRouteWithStopovers(start, end, stopovers);
      return res.json({ path: allPaths });
    } else {
      // 경유지가 없는 경우: 직접 경로 계산
      const path = await calculateDirectRoute(start, end);
      return res.json({ path });
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
    startX: start.lng.toString(),
    startY: start.lat.toString(),
    endX: end.lng.toString(),
    endY: end.lat.toString(),
    startName: '출발지',
    endName: '도착지',
    reqCoordType: 'WGS84GEO',
    resCoordType: 'WGS84GEO',
    searchOption: '0'  // 0: 추천경로, 4: 편안한길, 8: 빠른길
  };

  const headers = {
    appKey: TMAP_APP_KEY,
    'Content-Type': 'application/json',
  };

  console.log('API 요청 데이터:', JSON.stringify(data, null, 2));

  const response = await axios.post(url, data, { headers });
  
  console.log('API 응답:', JSON.stringify(response.data, null, 2));

  // T-Map 도보 경로 API 응답 구조 확인
  if (!response.data || !response.data.features) {
    throw new Error('유효하지 않은 API 응답');
  }

  const path = [];
  
  // features 배열에서 좌표 정보 추출
  response.data.features.forEach(feature => {
    if (feature.geometry && feature.geometry.coordinates) {
      if (feature.geometry.type === 'LineString') {
        // LineString인 경우 좌표 배열
        feature.geometry.coordinates.forEach(coord => {
          path.push({ lat: coord[1], lng: coord[0] });
        });
      } else if (feature.geometry.type === 'Point') {
        // Point인 경우 단일 좌표
        const coord = feature.geometry.coordinates;
        path.push({ lat: coord[1], lng: coord[0] });
      }
    }
  });

  return path;
}

// 경유지가 있는 경우 단계별 경로 계산
async function calculateRouteWithStopovers(start, end, stopovers) {
  const waypoints = [start, ...stopovers, end];
  const allPaths = [];

  // 각 구간별로 경로 계산
  for (let i = 0; i < waypoints.length - 1; i++) {
    const segmentStart = waypoints[i];
    const segmentEnd = waypoints[i + 1];
    
    try {
      const segmentPath = await calculateDirectRoute(segmentStart, segmentEnd);
      
      // 첫 번째 구간이 아닌 경우, 시작점은 제외 (중복 방지)
      if (i > 0 && segmentPath.length > 0) {
        segmentPath.shift();
      }
      
      allPaths.push(...segmentPath);
    } catch (error) {
      console.error(`구간 ${i}-${i+1} 경로 계산 실패:`, error.message);
      // 실패한 구간은 직선으로 연결
      if (i === 0 || allPaths.length === 0) {
        allPaths.push({ lat: segmentStart.lat, lng: segmentStart.lng });
      }
      allPaths.push({ lat: segmentEnd.lat, lng: segmentEnd.lng });
    }
  }

  return allPaths;
}

module.exports = router;