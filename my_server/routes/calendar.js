const express = require('express');
const router = express.Router();
const db = require('../config/database');

//특정 사용자의 일정 조회 (리더 및 멤버 일정 포함)
router.get('/:username/events', async (req, res) => {
    const { username } = req.params;
    const { start_date, end_date } = req.query; // 시작 날짜와 종료 날짜 필터링 (선택사항)

    try {
        // 사용자의 role과 관계 정보 조회
        const [userInfo] = await db.promise().query(
            `SELECT u.user_id, u.role, 
                 COALESCE(r.leader_id, u.user_id) AS leader_id
            FROM users u
              LEFT JOIN relationships r ON r.member_id = u.user_id
             WHERE u.username = ?`,
            [username]
        );

        if (userInfo.length === 0) {
            return res
                .status(404)
                .json({ message: '사용자를 찾을 수 없습니다.' });
        }

        const leaderId = userInfo[0].leader_id;

        // 일정 조회 쿼리 (리더와 연결된 모든 멤버 포함)
        let query = `
        SELECT DISTINCT 
        e.event_id, 
        e.title, 
        e.start_date, 
        e.end_date, 
        e.start_time, 
        e.end_time, 
        e.color, 
        e.all_day,  -- all_day 필드 추가
        u.username
        FROM calendar_events e
        JOIN users u ON e.user_id = u.user_id
        LEFT JOIN relationships r ON u.user_id = r.member_id
        WHERE 
        (u.user_id = ? OR r.leader_id = ?) 
        OR
        (e.user_id IN (SELECT member_id FROM relationships WHERE leader_id = ?))`;

        const params = [leaderId, leaderId, leaderId];

        // 날짜 필터링 추가 (start_date, end_date가 있으면 해당 날짜 범위로 필터링)
        if (start_date && end_date) {
            query += ` AND e.start_date >= ? AND e.end_date <= ?`;
            params.push(start_date, end_date);
        }

        const [events] = await db.promise().query(query, params);

        return res.status(200).json(events); // `all_day`는 그대로 사용
    } catch (error) {
        res.status(500).json({ message: '일정을 불러오는데 실패했습니다.' });
    }
});

// 일정 추가
router.post('/', async (req, res) => {
    const {
        username,
        title,
        start_date,
        end_date,
        start_time,
        end_time,
        color,
        all_day, // 하루 종일 여부 추가
    } = req.body;

    if (
        !username ||
        !title ||
        !start_date ||
        !end_date ||
        !start_time ||
        !end_time ||
        !color
    ) {
        return res
            .status(400)
            .json({ message: '모든 필드를 입력해야 합니다.' });
    }

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

        // 일정 추가 (user_id 사용)
        await db
            .promise()
            .query(
                'INSERT INTO calendar_events (user_id, title, start_date, end_date, start_time, end_time, color, all_day) VALUES (?, ?, ?, ?, ?, ?, ?, ?)',
                [
                    user[0].user_id, // user_id로 변경
                    title,
                    start_date,
                    end_date,
                    start_time,
                    end_time,
                    color,
                    all_day, // all_day 값 추가
                ]
            );
        res.status(201).json({ message: '일정이 추가되었습니다.' });
    } catch (error) {
        console.error('Error adding event:', error);
        res.status(500).json({ message: '서버 오류' });
    }
});

// 일정 수정
router.put('/edit/:event_id', async (req, res) => {
    const { event_id } = req.params;
    const {
        title,
        start_date,
        end_date,
        start_time,
        end_time,
        color,
        all_day,
    } = req.body;

    // 필수 필드 검증
    if (
        !title ||
        !start_date ||
        !end_date ||
        !start_time ||
        !end_time ||
        !color
    ) {
        return res.status(400).json({
            message: '모든 필드를 입력해야 합니다.',
        });
    }

    try {
        const [result] = await db
            .promise()
            .query(
                'UPDATE calendar_events SET title = ?, start_date = ?, end_date = ?, start_time = ?, end_time = ?, color = ?, all_day = ? WHERE event_id = ?',
                [
                    title,
                    start_date,
                    end_date,
                    start_time,
                    end_time,
                    color,
                    all_day,
                    event_id,
                ]
            );

        if (result.affectedRows === 0) {
            return res.status(404).json({
                message: '일정을 찾을 수 없습니다.',
            });
        }

        res.json({ message: '일정이 수정되었습니다.' });
    } catch (error) {
        console.error('Error updating event:', error);
        res.status(500).json({ message: '서버 오류' });
    }
});

// 일정 삭제
router.delete('/:username/delete/:event_id', async (req, res) => {
    const { event_id } = req.params;
    console.log('Received DELETE request for event ID:', event_id); // 디버깅: 이벤트 ID 확인

    try {
        const [result] = await db
            .promise()
            .query('DELETE FROM calendar_events WHERE event_id = ?', [
                event_id,
            ]);

        console.log('Delete result:', result); // 디버깅: 쿼리 결과 확인

        if (result.affectedRows === 0) {
            console.log('Event not found for deletion'); // 디버깅: 삭제할 이벤트가 없을 경우
            return res
                .status(404)
                .json({ message: '일정을 찾을 수 없습니다.' });
        }

        res.json({ message: '일정이 삭제되었습니다.' });
    } catch (error) {
        console.error('Error deleting event:', error); // 에러 로그 출력
        res.status(500).json({ message: '서버 오류' });
    }
});

module.exports = router;
