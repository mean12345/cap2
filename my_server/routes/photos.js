const express = require('express');
const router = express.Router();
const db = require('../config/database');
const { photoUpload } = require('../config/multerConfig');
const path = require('path');
const fs = require('fs');

router.post('/', photoUpload.single('photo'), async (req, res) => {
    const { username } = req.body;

    try {
        // 사용자 ID 조회
        const [user] = await db
            .promise()
            .query('SELECT user_id, role FROM users WHERE username = ?', [
                username,
            ]);

        if (user.length === 0) {
            return res
                .status(404)
                .json({ message: '사용자를 찾을 수 없습니다.' });
        }

        // 사진 정보 저장 (URL 형식 수정)
        const photoUrl = `${process.env.BASE_URL}/photo_share/${req.file.filename}`; // URL 형식 변경
        const [result] = await db
            .promise()
            .query(
                'INSERT INTO photos (user_id, photo_url, upload_date) VALUES (?, ?, NOW())',
                [user[0].user_id, photoUrl]
            );

        res.status(201).json({
            message: '사진이 업로드되었습니다',
            photo: {
                id: result.insertId,
                photoUrl: photoUrl,
            },
        });
    } catch (error) {
        console.error('Error uploading photo:', error);
        res.status(500).json({ message: '서버 오류가 발생했습니다' });
    }
});

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

        // 연관된 사용자들의 사진 조회 (리더의 사진 + 멤버들의 사진)
        const [photos] = await db.promise().query(
            `SELECT DISTINCT p.*, u.username
          FROM photos p
          JOIN users u ON p.user_id = u.user_id
          WHERE 
              u.user_id = ?  -- 리더 본인의 사진
              OR 
              u.user_id IN (  -- 멤버들의 사진
                  SELECT member_id 
                  FROM relationships 
                  WHERE leader_id = ?
              )
              OR
              (  -- 리더의 사진 (멤버인 경우)
                  u.user_id = (
                      SELECT leader_id 
                      FROM relationships 
                      WHERE member_id = (
                          SELECT user_id 
                          FROM users 
                          WHERE username = ?
                      )
                  )
              )
          ORDER BY p.upload_date DESC`,
            [leaderId, leaderId, username]
        );

        res.status(200).json(photos);
    } catch (error) {
        console.error('Error fetching photos:', error);
        res.status(500).json({
            message: '사진 목록을 불러오는데 실패했습니다.',
        });
    }
});
// 사진 삭제
router.delete('/:photoId', async (req, res) => {
    const { username } = req.body;
    const { photoId } = req.params;

    try {
        // 트랜잭션 시작
        await db.promise().query('START TRANSACTION');

        // 사진 정보와 작성자 확인
        const [photo] = await db.promise().query(
            `SELECT p.*, u.username, p.photo_url 
            FROM photos p 
            JOIN users u ON p.user_id = u.user_id 
            WHERE p.photo_id = ?`,
            [photoId]
        );

        if (photo.length === 0) {
            await db.promise().query('ROLLBACK');
            return res
                .status(404)
                .json({ message: '사진을 찾을 수 없습니다.' });
        }

        if (photo[0].username !== username) {
            await db.promise().query('ROLLBACK');
            return res.status(403).json({ message: '삭제 권한이 없습니다.' });
        }

        if (photo[0].photo_url) {
            const imagePath = photo[0].photo_url.split('/photo_share/')[1];
            const fullPath = path.join(__dirname, '../photo_share', imagePath);

            console.log('Full image path:', fullPath); // 경로가 올바르게 수정되었는지 확인

            if (fs.existsSync(fullPath)) {
                fs.unlinkSync(fullPath);
                console.log('File deleted:', fullPath);
            } else {
                console.log('File not found:', fullPath);
            }
        }

        // DB에서 사진 정보 삭제
        await db
            .promise()
            .query('DELETE FROM photos WHERE photo_id = ?', [photoId]);

        // 트랜잭션 완료
        await db.promise().query('COMMIT');

        res.status(200).json({ message: '사진이 삭제되었습니다.' });
    } catch (error) {
        await db.promise().query('ROLLBACK');
        console.error('Error deleting photo:', error);
        res.status(500).json({ message: '사진 삭제에 실패했습니다.' });
    }
});
module.exports = router;
