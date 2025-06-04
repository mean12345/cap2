const express = require('express');
const router = express.Router();
const db = require('../config/database');

//마커 저장
router.post('/', async (req, res) => {
    const { username, latitude, longitude, marker_type, marker_name } =
        req.body;
    console.log('Received post data:', {
        username,
        latitude,
        longitude,
        marker_type,
        marker_name,
    }); // 디버깅용 로그

    try {
        // 사용자 ID 조회
        const [user] = await db
            .promise()
            .query('SELECT user_id FROM users WHERE username = ?', [username]);

        if (user.length === 0) {
            return res
                .status(404)
                .json({ message: '사용자를 찾을 수 없습니다.' });
        }

        // 마커 저장
        const [result] = await db
            .promise()
            .query(
                'INSERT INTO markers (user_id, latitude, longitude, marker_type, marker_name) VALUES (?, ?, ?, ?, ?)',
                [user[0].user_id, latitude, longitude, marker_type, marker_name]
            );

        console.log('Post created:', result); // 디버깅용 로그

        res.status(201).json({
            message: '마커가 저장되었습니다.',
            post_id: result.insertId,
        });
    } catch (error) {
        console.error('Error saving markers:', error);
        res.status(500).json({ message: '마커커 저장에 실패했습니다.' });
    }
});

// 마커 조회
router.get('/:username', async (req, res) => {
    const { username } = req.params;

    try {
        // 사용자의 role과 관계 정보 조회
        const [userInfo] = await db.promise().query(
            `SELECT u.user_id, u.role, 
              CASE 
                  WHEN u.role = 'leader' THEN u.user_id
                  ELSE (SELECT leader_id FROM relationships WHERE member_id = u.user_id)
              END as leader_id
             FROM users u
             WHERE u.username = ?`,
            [username]
        );

        if (userInfo.length === 0) {
            return res
                .status(404)
                .json({ message: '사용자를 찾을 수 없습니다.' });
        }

        const leaderId = userInfo[0].leader_id;

        // 마커 조회 쿼리 - marker_name도 포함
        const [markers] = await db.promise().query(
            `SELECT m.latitude, m.longitude, m.marker_type, m.marker_name
             FROM markers m
             JOIN users u ON m.user_id = u.user_id
             LEFT JOIN relationships r ON u.user_id = r.member_id
             WHERE 
               (u.user_id = ? OR r.leader_id = ?) 
               OR
               (m.user_id IN (SELECT member_id FROM relationships WHERE leader_id = ?))`,
            [leaderId, leaderId, leaderId]
        );

        if (markers.length === 0) {
            return res.status(200).json({ message: '마커가 없습니다.' });
        }

        res.status(200).json({
            message: '마커가 로드되었습니다.',
            markers: markers,
        });
    } catch (error) {
        console.error('Error loading markers:', error);
        res.status(500).json({ message: '마커 로드에 실패했습니다.' });
    }
});


//마커 삭제
router.delete('/:marker_name', async (req, res) => {
    const { marker_name } = req.params;
    console.log('Received delete request for marker_name:', marker_name); // 디버깅용 로그

    try {
        // 마커 존재 여부 확인
        const [marker] = await db
            .promise()
            .query('SELECT * FROM markers WHERE marker_name = ?', [
                marker_name,
            ]);

        if (marker.length === 0) {
            return res
                .status(404)
                .json({ message: '마커를 찾을 수 없습니다.' });
        }

        // 마커 삭제
        await db
            .promise()
            .query('DELETE FROM markers WHERE marker_name = ?', [marker_name]);

        console.log('Marker deleted:', marker_name); // 디버깅용 로그
        res.status(200).json({ message: '마커가 삭제되었습니다.' });
    } catch (error) {
        console.error('Error deleting marker:', error);
        res.status(500).json({ message: '마커 삭제에 실패했습니다.' });
    }
});

//마커 이름 조회
router.post('/getMarkerName', (req, res) => {
    const { latitude, longitude } = req.body;

    // 요청 데이터 검증
    if (latitude == null || longitude == null) {
        console.error('[ERROR] 요청에 위도 또는 경도가 없습니다.');
        return res
            .status(400)
            .json({ error: '위도와 경도를 제공해야 합니다.' });
    }

    console.log(`[INFO] 요청받은 위도: ${latitude}, 경도: ${longitude}`);

    // SQL 쿼리 작성
    const query =
        'SELECT marker_name FROM markers WHERE latitude = ? AND longitude = ? LIMIT 1';

    // 쿼리 실행
    db.query(query, [latitude, longitude], (err, result) => {
        if (err) {
            console.error('[ERROR] 쿼리 실행 오류:', err);
            return res.status(500).json({ error: '서버 내부 오류' });
        }

        console.log(`[INFO] 쿼리 실행 결과: ${JSON.stringify(result)}`);

        if (result.length > 0) {
            // 겹치는 마커가 있으면 marker_name 반환
            return res.json({ marker_name: result[0].marker_name });
        } else {
            // 겹치는 마커가 없으면 빈 응답
            console.log('[INFO] 겹치는 마커 없음');
            return res.json({ marker_name: null });
        }
    });
});

module.exports = router;
