// 방문자 경로를 *Greedy TSP 알고리즘으로 정렬
// 주어진 지점들 중에서 가장 가까운 지점부터 차례로 방문
// 마지막 지점에서 다시 시작점으로 돌아오는 순환루트

function greedyTSP(points) {
  if (!points.length) return [];

  const visited = [points[0]];
  const unvisited = points.slice(1);

  while (unvisited.length > 0) {
    const last = visited[visited.length - 1];
    const next = unvisited.reduce((prev, curr) => {
      const dPrev = Math.hypot(prev.lat - last.lat, prev.lon - last.lon);
      const dCurr = Math.hypot(curr.lat - last.lat, curr.lon - last.lon);
      return dCurr < dPrev ? curr : prev;
    });
    visited.push(next);
    unvisited.splice(unvisited.indexOf(next), 1);
  }
  // 다시 시작점으로 돌아옴
  visited.push(points[0])

  return visited;
}

module.exports = { greedyTSP };
