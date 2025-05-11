const express = require('express');
const router = express.Router();
const db = require('../config/database');

//기록 저장
router.post('/saveTrack', async (req, res) => {
    const { username, startTime, endTime, distance, stepCount } = req.body;
    console.log('Received post data:', {
        username,
        startTime,
        endTime,
        distance,
        stepCount,
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

        // 기록 저장
        const [result] = await db
            .promise()
            .query(
                'INSERT INTO tracking_data (user_id, start_time, end_time, distance, step_count) VALUES (?, ?, ?, ?, ?)',
                [user[0].user_id, startTime, endTime, distance, stepCount]
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

    try {
        // 사용자 ID와 리더 ID 조회
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

        // tracking_data 조회
        const [trackingData] = await db.promise().query(
            `SELECT DISTINCT
              t.track_id,
              t.user_id,
              u.username,
              t.start_time,
              t.end_time,
              t.distance,
              t.step_count,
              t.created_at
             FROM tracking_data t
             JOIN users u ON t.user_id = u.user_id
             LEFT JOIN relationships r ON u.user_id = r.member_id
             WHERE 
               (u.user_id = ? OR r.leader_id = ?) 
               OR
               (t.user_id IN (SELECT member_id FROM relationships WHERE leader_id = ?))
             ORDER BY t.created_at DESC`,
            [leaderId, leaderId, leaderId]
        );

        // 날짜 포맷 변경
        const formattedData = trackingData.map((data) => ({
            ...data,
            start_time: new Date(data.start_time).toLocaleString(),
            end_time: new Date(data.end_time).toLocaleString(),
            created_at: new Date(data.created_at).toLocaleString(),
        }));

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

//기록 평균값 조회
router.get('/avg/:username', async (req, res) => {
    const { username } = req.params;

    try {
        console.log(`Received request for username: ${username}`);

        //username -> user_id 가져오기
        const [userInfo] = await db
            .promise()
            .query(`SELECT user_id FROM users WHERE username = ?`, [username]);

        if (userInfo.length === 0) {
            return res
                .status(404)
                .json({ message: '사용자를 찾을 수 없습니다.' });
        }

        const userId = userInfo[0].user_id;

        //user_id가 속한 그룹의 leader_id 찾기
        const [relationship] = await db
            .promise()
            .query(
                `SELECT leader_id FROM relationships WHERE member_id = ? UNION SELECT ? AS leader_id WHERE EXISTS (SELECT 1 FROM relationships WHERE leader_id = ?)`,
                [userId, userId, userId]
            );

        if (relationship.length === 0) {
            return res.status(404).json({
                message: '사용자가 속한 그룹이 없습니다.',
            });
        }

        const leaderId = relationship[0].leader_id;

        //leader_id를 기준으로 그 그룹의 모든 member_id 가져오기
        const [groupMembers] = await db
            .promise()
            .query(`SELECT member_id FROM relationships WHERE leader_id = ?`, [
                leaderId,
            ]);

        const memberIds = groupMembers.map((row) => row.member_id);

        //groupMembers가 비어있을 수 있으니, leader 포함.
        memberIds.push(leaderId);

        console.log('Group Member IDs:', memberIds);

        //그룹의 모든 멤버들의 활동 데이터 평균값 계산
        const [trackingData] = await db.promise().query(
            `SELECT 
                AVG(distance) AS avg_distance,
                AVG(step_count) AS avg_steps,
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
            return res.status(404).json({
                message: '이번 달의 데이터가 없습니다.',
            });
        }

        res.status(200).json({
            avg_distance: trackingData[0].avg_distance || 0,
            avg_steps: trackingData[0].avg_steps || 0,
            avg_time_minutes: trackingData[0].avg_time_minutes || 0,
        });
    } catch (error) {
        console.error('Error fetching group stats:', error);
        res.status(500).json({ message: '데이터를 불러오는데 실패했습니다.' });
    }
});

module.exports = router;
