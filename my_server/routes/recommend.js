const express = require('express');
const router = express.Router();
const db = require('../config/database');
const proj4 = require("proj4");
const { greedyTSP } = require('./greedTSP'); // ✅ 모듈 가져오기

// EPSG:5186 정의 (한국 중부 원점 기준)
proj4.defs("EPSG:5186", "+proj=tmerc +lat_0=38 +lon_0=127 +k=1 +x_0=1000000 +y_0=2000000 +ellps=GRS80 +units=m +no_defs");

// 경로 추천 API
router.get('/recommend-path', async (req, res) => {
  try {
    // 1. 방문자 수 많은 상위 5개 grid_id + 중심 좌표 x/y
    const [rows] = await db.promise().query(`
      SELECT grid_id, ST_X(ST_Centroid(SHAPE)) AS x, ST_Y(ST_Centroid(SHAPE)) AS y
      FROM grid_table
      ORDER BY visit_count DESC
      LIMIT 5
    `);

    // 2. 좌표 변환 EPSG:5186 → EPSG:4326
    const points = rows.map(row => {
      const [lon, lat] = proj4("EPSG:5186", "WGS84", [row.x, row.y]);
      return { grid_id: row.grid_id, lat, lon };
    });

    // 3. Greedy 알고리즘 호출 
    const route = greedyTSP(points);

    res.json({
      message: "추천 경로입니다.",
      route: route
    });

  } catch (err) {
    console.error("경로 추천 오류:", err);
    res.status(500).json({ message: "서버 오류" });
  }
});

module.exports = router;
