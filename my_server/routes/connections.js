const express = require('express');
const router = express.Router();
const db = require('../config/database');

// 초대 코드 생성
router.post('/connection-codes', (req, res) => {
    const { username } = req.body;

    // 사용자 확인 및 role 체크
    db.query(
        'SELECT user_id, role FROM users WHERE username = ?',
        [username],
        (err, results) => {
            if (err) {
                console.error('Error checking user:', err);
                return res
                    .status(500)
                    .send({ message: '서버 오류가 발생했습니다.' });
            }

            if (results.length === 0) {
                return res
                    .status(404)
                    .send({ message: '사용자를 찾을 수 없습니다.' });
            }

            const user = results[0];
            if (user.role !== 'leader') {
                return res
                    .status(403)
                    .send({ message: '초대 코드 생성 권한이 없습니다.' });
            }

            // 랜덤 초대 코드 생성 (6자리)
            const connectionCode = Math.random()
                .toString(36)
                .substring(2, 8)
                .toUpperCase();

            // 10분 후 만료
            const expiresAt = new Date();
            expiresAt.setMinutes(expiresAt.getMinutes() + 10);

            // 초대 코드 저장
            db.query(
                'INSERT INTO connection_codes (leader_id, connection_code, expires_at) VALUES (?, ?, ?)',
                [user.user_id, connectionCode, expiresAt],
                (err, result) => {
                    if (err) {
                        console.error('Error creating connection code:', err);
                        return res.status(500).send({
                            message: '초대 코드 생성 중 오류가 발생했습니다.',
                        });
                    }

                    res.status(201).send({
                        code: connectionCode,
                        expires_at: expiresAt,
                    });
                }
            );
        }
    );
});

// 초대 코드 사용
router.post('/connect', async (req, res) => {
    const { username, connectionCode } = req.body;

    try {
        await db.promise().query('START TRANSACTION');

        // 초대 코드 유효성 확인
        const [codeInfo] = await db
            .promise()
            .query(
                'SELECT * FROM connection_codes WHERE connection_code = ? AND expires_at > NOW()',
                [connectionCode]
            );

        if (codeInfo.length === 0) {
            await db.promise().query('ROLLBACK');
            return res
                .status(400)
                .json({ message: '유효하지 않거나 만료된 초대 코드입니다.' });
        }

        // 사용자 정보 확인
        const [user] = await db
            .promise()
            .query('SELECT user_id, role FROM users WHERE username = ?', [
                username,
            ]);

        if (user.length === 0) {
            await db.promise().query('ROLLBACK');
            return res
                .status(404)
                .json({ message: '사용자를 찾을 수 없습니다.' });
        }

        // 이미 다른 리더와 연결되어 있는지 확인
        const [existingRelation] = await db
            .promise()
            .query('SELECT * FROM relationships WHERE member_id = ?', [
                user[0].user_id,
            ]);

        if (existingRelation.length > 0) {
            // 기존 게시글에 연결된 이미지 파일 삭제
            const [posts] = await db
                .promise()
                .query('SELECT image_url FROM posts WHERE user_id = ?', [
                    user[0].user_id,
                ]);

            // 이미지 파일 삭제
            for (const post of posts) {
                if (post.image_url) {
                    const imagePath = post.image_url.split('/uploads/')[1];
                    const fullPath = path.join(__dirname, 'uploads', imagePath);
                    if (fs.existsSync(fullPath)) {
                        fs.unlinkSync(fullPath);
                    }
                }
            }

            // 기존 게시글 삭제
            await db
                .promise()
                .query('DELETE FROM posts WHERE user_id = ?', [
                    user[0].user_id,
                ]);

            // 기존 관계 삭제
            await db
                .promise()
                .query('DELETE FROM relationships WHERE member_id = ?', [
                    user[0].user_id,
                ]);
        }

        // 새로운 관계 생성
        await db
            .promise()
            .query(
                'INSERT INTO relationships (leader_id, member_id) VALUES (?, ?)',
                [codeInfo[0].leader_id, user[0].user_id]
            );

        // 사용자 역할을 member로 변경
        await db
            .promise()
            .query('UPDATE users SET role = "member" WHERE user_id = ?', [
                user[0].user_id,
            ]);

        // 초대 코드는 삭제하지 않음 (10분 후 자동 만료)

        await db.promise().query('COMMIT');
        res.status(200).json({ message: '연동이 완료되었습니다.' });
    } catch (error) {
        await db.promise().query('ROLLBACK');
        console.error('Error connecting:', error);
        res.status(500).json({ message: '연동에 실패했습니다.' });
    }
});

module.exports = router;
