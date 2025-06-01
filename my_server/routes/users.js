const express = require('express');
const router = express.Router();
const bcrypt = require('bcrypt');
const db = require('../config/database');
const path = require('path');
const fs = require('fs');
const { profilestorage } = require('../config/multerConfig');

// 사용자 추가
router.post('/', async (req, res) => {
    try {
        const { username, email, password, nickname } = req.body;

        const emailPattern = /^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$/;
        if (!emailPattern.test(email)) {
            return res
                .status(400)
                .send({ message: '유효한 이메일 형식이 아닙니다.' });
        }

        const [existingUser] = await db
            .promise()
            .query('SELECT * FROM users WHERE email = ?', [email]);
        if (existingUser.length > 0) {
            return res
                .status(400)
                .send({ message: '이미 사용 중인 이메일입니다.' });
        }
        const [existingUserByUsername] = await db
            .promise()
            .query('SELECT * FROM users WHERE username = ?', [username]);
        if (existingUserByUsername.length > 0) {
            return res
                .status(400)
                .send({ message: '이미 사용 중인 사용자명입니다.' });
        }

        const hashedPassword = await bcrypt.hash(password, 10);
        const [result] = await db
            .promise()
            .query(
                'INSERT INTO users (username, email, password, nickname) VALUES (?, ?, ?, ?)',
                [username, email, hashedPassword, nickname]
            );

        res.status(201).send({
            id: result.insertId,
            username,
            email,
            nickname,
        });
    } catch (err) {
        console.error(err);
        res.status(500).send({ message: '서버 오류가 발생했습니다.' });
    }
});

// 로그인
router.post('/login', (req, res) => {
    const { username, password } = req.body;

    db.query(
        'SELECT * FROM users WHERE username = ?',
        [username],
        (err, results) => {
            if (err) return res.status(500).send(err);
            if (results.length === 0) {
                return res
                    .status(400)
                    .send({ message: '사용자를 찾을 수 없습니다.' });
            }

            const user = results[0];
            bcrypt.compare(password, user.password, (err, isMatch) => {
                if (err) return res.status(500).send(err);
                if (!isMatch) {
                    return res
                        .status(400)
                        .send({ message: '비밀번호가 일치하지 않습니다.' });
                }
                res.status(200).send({ message: '로그인 성공' });
            });
        }
    );
});

// 계정 삭제
router.delete('/:username', async (req, res) => {
    const { username } = req.params;

    try {
        await db.promise().query('START TRANSACTION');

        // 사용자 확인
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

        // 사용자의 게시글에 연결된 이미지 파일 삭제
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

        // 사용자의 게시글 삭제
        await db
            .promise()
            .query('DELETE FROM posts WHERE user_id = ?', [user[0].user_id]);

        // 리더인 경우 초대 코드 삭제
        if (user[0].role === 'leader') {
            await db
                .promise()
                .query('DELETE FROM connection_codes WHERE leader_id = ?', [
                    user[0].user_id,
                ]);
        }

        // 연동 관계 삭제
        // 리더인 경우 모든 멤버와의 관계 삭제
        if (user[0].role === 'leader') {
            await db
                .promise()
                .query('DELETE FROM relationships WHERE leader_id = ?', [
                    user[0].user_id,
                ]);
        }
        // 멤버인 경우 리더와의 관계 삭제
        else {
            await db
                .promise()
                .query('DELETE FROM relationships WHERE member_id = ?', [
                    user[0].user_id,
                ]);
        }

        // 사용자 계정 삭제
        await db
            .promise()
            .query('DELETE FROM users WHERE user_id = ?', [user[0].user_id]);

        await db.promise().query('COMMIT');
        res.status(200).json({ message: '계정이 성공적으로 삭제되었습니다.' });
    } catch (error) {
        await db.promise().query('ROLLBACK');
        console.error('Error deleting user:', error);
        res.status(500).json({ message: '계정 삭제 중 오류가 발생했습니다.' });
    }
});

//프로필 사진 업로드
router.post(
    '/upload_profile_picture',
    profilestorage.single('profile_picture'),
    (req, res) => {
        if (!req.file) {
            return res.status(400).json({ message: '파일이 없습니다.' });
        }

        // 이미지 URL 생성
        const profileUrl = `${process.env.BASE_URL}/profile_uploads/${req.file.filename}`;
        console.log('Generated image URL:', profileUrl);

        // URL을 클라이언트에 반환
        res.status(200).json({ url: profileUrl });
    }
);
// 리더 아이디 찾기
router.get('/get_leader_id', (req, res) => {
    const { username } = req.query;

    if (!username) {
        return res.status(400).json({ error: 'Username is required' });
    }

    const query = `
        SELECT r.leader_id
        FROM relationships r
        JOIN users u ON r.member_id = u.user_id
        WHERE u.username = ?`;
    
    db.query(query, [username], (err, results) => {
        if (err) {
            console.error('Error fetching leader id:', err);
            return res.status(500).json({ error: 'Database error' });
        }

        if (results.length === 0) {
            return res.status(404).json({ error: 'User is not a member or no leader found' });
        }

        const leaderId = results[0].leader_id;
        res.json({ leader_id: leaderId });
    });
});

// 프로필 사진 업로드 및 정보 업데이트 통합
router.post(
    '/update_profile',
    profilestorage.single('profile_picture'),
    async (req, res) => {
        try {
            const { username, nickname } = req.body;
            let profile_picture = null;

            // 새 파일이 업로드된 경우
            if (req.file) {
                // 기존 프로필 사진 URL 조회
                const [oldProfile] = await db
                    .promise()
                    .query(
                        'SELECT profile_picture FROM users WHERE username = ?',
                        [username]
                    );

                // 기존 이미지가 있는 경우 삭제
                if (oldProfile[0]?.profile_picture) {
                    const oldImagePath =
                        oldProfile[0].profile_picture.split(
                            '/profile_uploads/'
                        )[1];
                    if (oldImagePath) {
                        const fullPath = path.join(
                            __dirname,
                            '../profile_uploads',
                            oldImagePath
                        );
                        if (fs.existsSync(fullPath)) {
                            fs.unlinkSync(fullPath); // 기존 파일 삭제
                            console.log(`Deleted profile picture: ${fullPath}`);
                        }
                    }
                }

                // 새 프로필 사진 URL 생성
                profile_picture = `${process.env.BASE_URL}/profile_uploads/${req.file.filename}`;
                console.log('Generated image URL:', profile_picture);
            }

            // 프로필 정보 업데이트 쿼리 작성
            let query = 'UPDATE users SET nickname = ?';
            let params = [nickname];

            // 새 프로필 사진이 있는 경우에만 업데이트에 포함
            if (profile_picture !== null) {
                query += ', profile_picture = ?';
                params.push(profile_picture);
            }
            query += ' WHERE username = ?';
            params.push(username);

            // DB 업데이트 실행
            const [result] = await db.promise().query(query, params);

            if (result.affectedRows === 0) {
                return res
                    .status(404)
                    .json({ message: '사용자를 찾을 수 없습니다.' });
            }

            res.status(200).json({
                message: '프로필이 성공적으로 업데이트되었습니다.',
                profile_picture: profile_picture,
            });
        } catch (error) {
            console.error('프로필 업데이트 오류:', error);
            res.status(500).json({
                message: '프로필 업데이트 중 오류가 발생했습니다.',
            });
        }
    }
);
//프로필 재설정
router.post('/reset_profile_picture', (req, res) => {
    const { username } = req.body;

    if (!username) {
        return res.status(400).json({ error: 'Username is required' });
    }

    // 기존 프로필 이미지 삭제
    const query = 'SELECT profile_picture FROM users WHERE username = ?';
    db.query(query, [username], (err, results) => {
        if (err) {
            return res.status(500).json({ error: 'Database error' });
        }

        if (results.length === 0) {
            return res.status(404).json({ error: 'User not found' });
        }

        const profileImageUrl = results[0].profile_picture;

        // 이미지 파일이 존재하는 경우 삭제
        if (profileImageUrl) {
            const imagePath = profileImageUrl.split('/profile_uploads/')[1];
            const fullImagePath = path.join(
                __dirname,
                '..',
                'profile_uploads',
                imagePath
            );

            if (fs.existsSync(fullImagePath)) {
                fs.unlinkSync(fullImagePath); // 파일 삭제
                console.log(`Deleted profile picture: ${fullImagePath}`);
            }
        }

        // 데이터베이스에서 프로필 이미지 URL을 null로 업데이트
        const updateQuery =
            'UPDATE users SET profile_picture = NULL WHERE username = ?';
        db.query(updateQuery, [username], (err, updateResults) => {
            if (err) {
                return res.status(500).json({ error: 'Database error' });
            }
            if (updateResults.affectedRows === 0) {
                return res.status(404).json({ error: 'User not found' });
            }
            res.json({ message: 'Profile picture reset to default' });
        });
    });
});

// username에 해당하는 nickname과 profile_picture 조회 API
router.get('/get_nickname', (req, res) => {
    const { username } = req.query;
    if (!username) {
        return res.status(400).json({ error: 'Username is required' });
    }

    const query =
        'SELECT nickname, profile_picture FROM users WHERE username = ?';
    db.query(query, [username], (err, results) => {
        if (err) {
            return res.status(500).json({ error: 'Database error' });
        }
        if (results.length === 0) {
            return res.status(404).json({ error: 'User not found' });
        }
        res.json({
            nickname: results[0].nickname,
            profile_picture: results[0].profile_picture,
        });
    });
});

// 관계 정보 조회
router.get('/:username/relationships', (req, res) => {
    const { username } = req.params;

    db.query(
        `SELECT u.role,
          CASE 
              WHEN u.role = 'leader' THEN (
                  SELECT GROUP_CONCAT(m.username)
                  FROM relationships r
                  JOIN users m ON r.member_id = m.user_id
                  WHERE r.leader_id = u.user_id
              )
              WHEN u.role = 'member' THEN (
                  SELECT l.username
                  FROM relationships r
                  JOIN users l ON r.leader_id = l.user_id
                  WHERE r.member_id = u.user_id
              )
          END as related_users,
          CASE
              WHEN u.role = 'member' THEN (
                  SELECT GROUP_CONCAT(m2.username)
                  FROM relationships r1
                  JOIN relationships r2 ON r1.leader_id = r2.leader_id
                  JOIN users m2 ON r2.member_id = m2.user_id
                  WHERE r1.member_id = u.user_id AND m2.username != u.username
              )
          END as other_members
      FROM users u
      WHERE u.username = ?`,
        [username],
        (err, results) => {
            if (err) {
                console.error('Error fetching relationships:', err);
                return res
                    .status(500)
                    .send({ message: '서버 오류가 발생했습니다.' });
            }

            if (results.length === 0) {
                return res
                    .status(404)
                    .send({ message: '사용자를 찾을 수 없습니다.' });
            }

            const result = results[0];
            const relatedUsers = result.related_users
                ? result.related_users.split(',')
                : [];
            const otherMembers = result.other_members
                ? result.other_members.split(',')
                : [];

            res.status(200).send({
                role: result.role,
                relatedUsers: relatedUsers,
                otherMembers: otherMembers,
            });
        }
    );
});

module.exports = router;
