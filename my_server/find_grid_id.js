console.log("✅ [DEBUG] find_grid_id.js 실행됨");

const fs = require("fs");
const path = require("path");
const turf = require("@turf/turf");

// === GeoJSON 불러오기 ===
const geojsonPath = path.join(__dirname, "../data/dalseo_200m.geojson");
const geojsonData = JSON.parse(fs.readFileSync(geojsonPath, "utf8"));

/**
 * 위경도 → grid_id 찾기
 */
function findGridId(lat, lon) {
  const point = turf.point([lon, lat]); // GeoJSON은 [lon, lat] 순서!
  for (const feature of geojsonData.features) {
    if (turf.booleanPointInPolygon(point, feature)) {
      return feature.properties.grid_id;
    }
  }
  return null;
}

// === 직접 실행 시 테스트 ===
if (require.main === module) {
  const lat = 35.8421;      // ✅ 실제 그리드 안쪽 테스트 좌표
  const lon = 128.5432;

  console.log("▶ 위도:", lat, "경도:", lon);
  const gridId = findGridId(lat, lon);

  if (gridId !== null) {
    console.log(`✅ 해당 위치는 grid_id: ${gridId} 에 포함됩니다.`);
  } else {
    console.log("❌ 해당 위치는 어떤 그리드에도 포함되지 않습니다.");
  }
}

module.exports = { findGridId };
