require('dotenv').config(); // .env 파일에서 DB 설정 불러오기
const fs = require('fs');
const path = require('path');
const mysql = require('mysql2/promise');

// GeoJSON 파일 경로 설정
const filePath = path.join(__dirname, '../data/dalseo_200m.geojson');
console.log("파일 경로:", filePath);

// GeoJSON 파일 로드 및 파싱
let geojson;

try {
  geojson = JSON.parse(fs.readFileSync(filePath, 'utf8'));
  console.log("GeoJSON 파일 로드 성공");
  console.log(" Feature 수:", geojson.features.length);
} catch (err) {
  console.error("GeoJSON 로드 실패:", err.message);
  process.exit(1);
}

// geometry → WKT 문자열 변환 함수 (괄호 3중 주의)
function geoJSONToWKT(geometry) {
  if (geometry.type === 'MultiPolygon') {
    const polygons = geometry.coordinates.map(polygon =>
      '(((' + polygon[0].map(coord => `${coord[0]} ${coord[1]}`).join(', ') + ')))'
    ).join(', ');
    return `MULTIPOLYGON(${polygons})`;
  }
  throw new Error('지원하지 않는 geometry 타입');
}

// DB 삽입 함수
async function insertGeoJSON() {
  let conn;

  try {
    conn = await mysql.createConnection({
      host: process.env.DB_HOST,
      user: process.env.DB_USER,
      password: process.env.DB_PASSWORD,
      database: process.env.DB_NAME
    });

    console.log("MySQL 연결 완료");

    for (const feature of geojson.features) {
      const grid_id = feature.properties.grid_id;
      const wkt = geoJSONToWKT(feature.geometry);

      console.log(`삽입 시도: grid_id=${grid_id}`);

      const query = `
        INSERT INTO grid_table (grid_id, geom, visit_count)
        VALUES (?, ST_GeomFromText(?, 4326), 0)
        ON DUPLICATE KEY UPDATE geom = VALUES(geom)
      `;

      try {
        await conn.execute(query, [grid_id.toString(), wkt]);
      } catch (insertErr) {
        console.error(`삽입 실패: grid_id=${grid_id}`);
        console.error("SQL 에러:", insertErr.message);
      }
    }

    console.log('GeoJSON → MySQL 저장 완료');
  } catch (connErr) {
    console.error("MySQL 연결 실패:", connErr.message);
  } finally {
    if (conn) await conn.end();
  }
}

// 실행
insertGeoJSON().catch(error => {
  console.error('전체 실행 실패:', error);
});
