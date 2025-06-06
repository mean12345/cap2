const express = require('express');
const router = express.Router();
const db = require('../config/database');

//기록 저장
router.post('/saveTrack', async (req, res) => {
    const { username, dog_id, startTime, endTime, distance, speed, path_data } = req.body;
    console.log('Received post data:', {
        username,
        dog_id,
        startTime,
        endTime,
        distance,
        speed,
        path_data,
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

        const pathDataStr = JSON.stringify(path_data);

const [result] = await db
    .promise()
    .query(
        'INSERT INTO tracking_data (user_id, dog_id, start_time, end_time, distance, speed, path_data) VALUES (?, ?, ?, ?, ?, ?, ?)',
        [user[0].user_id, dog_id, startTime, endTime, distance, speed, pathDataStr]
    );

        console.log('Post created:', result); // 디버깅용 로그

        res.status(201).json({
            message: '기록이 저장되었습니다.',
            post_id: result.insertId,
        });
    } catch (error) {
        console.error('Error saving track data:', error);
        res.status(500).json({ message: '기록 저장에 실패했습니다.' });
    }
});

//기록 조회
router.get('/:username', async (req, res) => {
    const { username } = req.params;
    const dogId = req.query.dog_id;

    try {
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
            return res.status(404).json({ message: '사용자를 찾을 수 없습니다.' });
        }

        const leaderId = userInfo[0].leader_id;

        let query = `
            SELECT DISTINCT
              t.track_id,
              t.user_id,
              u.username,
              t.start_time,
              t.end_time,
              t.distance,
              IFNULL(t.speed, 0) AS speed,
              t.path_data,
              t.created_at
            FROM tracking_data t
            JOIN users u ON t.user_id = u.user_id
            LEFT JOIN relationships r ON u.user_id = r.member_id
            WHERE 
              (
                (u.user_id = ? OR r.leader_id = ?) 
                OR
                (t.user_id IN (SELECT member_id FROM relationships WHERE leader_id = ?))
              )
        `;
        const params = [leaderId, leaderId, leaderId];

        if (dogId) {
            query += ' AND t.dog_id = ?';
            params.push(dogId);
        }

        query += ' ORDER BY t.created_at DESC';

        const [trackingData] = await db.promise().query(query, params);

        const formattedData = trackingData.map((data) => {
            let parsedPathData = [];
            try {
                // path_data가 문자열인 경우에만 파싱
                if (typeof data.path_data === 'string') {
                    parsedPathData = JSON.parse(data.path_data);
                } else if (Array.isArray(data.path_data)) {
                    // 이미 배열인 경우 그대로 사용
                    parsedPathData = data.path_data;
                }
            } catch (e) {
                console.error('path_data 파싱 오류:', e);
            }

            return {
                ...data,
                start_time: new Date(data.start_time).toLocaleString(),
                end_time: new Date(data.end_time).toLocaleString(),
                created_at: new Date(data.created_at).toLocaleString(),
                speed: data.speed,
                path_data: parsedPathData,
            };
        });

        res.status(200).json(formattedData);
    } catch (error) {
        console.error('Error fetching tracking data:', error);
        res.status(500).json({
            message: 'tracking_data 목록을 불러오는데 실패했습니다.',
        });
    }
});


//산책 기록 삭제
router.delete('/:id', (req, res) => {
    const { id } = req.params;
    db.query(
        'DELETE FROM tracking_data WHERE track_id = ?',
        [id],
        (err, result) => {
            if (err) return res.status(500).json(err);
            res.json({ message: '삭제 완료', result });
        }
    );
});

// 기록 평균값 조회 (속력 포함)
router.get('/avg/:username', async (req, res) => {
    const { username } = req.params;

    try {
        console.log(`Received request for username: ${username}`);

        // username -> user_id 가져오기
        const [userInfo] = await db
            .promise()
            .query(`SELECT user_id FROM users WHERE username = ?`, [username]);

        if (userInfo.length === 0) {
            return res.status(404).json({ message: '사용자를 찾을 수 없습니다.' });
        }

        const userId = userInfo[0].user_id;

        // user_id가 속한 그룹의 leader_id 찾기
        const [relationship] = await db
            .promise()
            .query(
                `SELECT leader_id FROM relationships WHERE member_id = ? 
                 UNION 
                 SELECT ? AS leader_id WHERE EXISTS (SELECT 1 FROM relationships WHERE leader_id = ?)`,
                [userId, userId, userId]
            );

        if (relationship.length === 0) {
            return res.status(404).json({ message: '사용자가 속한 그룹이 없습니다.' });
        }

        const leaderId = relationship[0].leader_id;

        // leader_id를 기준으로 그 그룹의 모든 member_id 가져오기
        const [groupMembers] = await db
            .promise()
            .query(`SELECT member_id FROM relationships WHERE leader_id = ?`, [leaderId]);

        const memberIds = groupMembers.map((row) => row.member_id);

        // groupMembers가 비어있을 수 있으니, leader 포함
        memberIds.push(leaderId);

        console.log('Group Member IDs:', memberIds);

        // 그룹의 모든 멤버들의 활동 데이터 평균값 계산
        const [trackingData] = await db.promise().query(
            `SELECT 
                AVG(distance) AS avg_distance,
                AVG(TIMESTAMPDIFF(SECOND, start_time, end_time)) / 60 AS avg_time_minutes
            FROM tracking_data 
            WHERE user_id IN (${memberIds.map(() => '?').join(', ')})
              AND created_at BETWEEN ? AND ?`,
            [
                ...memberIds,
                new Date(new Date().setDate(1))
                    .toISOString()
                    .slice(0, 19)
                    .replace('T', ' '),
                new Date(new Date().setMonth(new Date().getMonth() + 1, 1))
                    .toISOString()
                    .slice(0, 19)
                    .replace('T', ' '),
            ]
        );

        if (!trackingData || trackingData.length === 0) {
            return res.status(404).json({ message: '이번 달의 데이터가 없습니다.' });
        }

        const avgDistance = trackingData[0].avg_distance || 0;       
        const avgTimeMin = trackingData[0].avg_time_minutes || 0;


        const avgSpeedKmh = (avgTimeMin > 0) ? (avgDistance * 60) / (1000 * avgTimeMin) : 0;

        res.status(200).json({
            avg_distance: avgDistance,
            avg_time_minutes: avgTimeMin,
            avg_speed_kmh: avgSpeedKmh,
        });
    } catch (error) {
        console.error('Error fetching group stats:', error);
        res.status(500).json({ message: '데이터를 불러오는데 실패했습니다.' });
    }
});


module.exports = router;
