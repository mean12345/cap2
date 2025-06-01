const express = require('express');
const router = express.Router();
const db = require('../config/database');
const { upload } = require('../config/multerConfig');
const path = require('path');
const fs = require('fs');

// 게시글 작성
router.post('/', async (req, res) => {
    const { username, content, image_url } = req.body;
    console.log('Received post data:', {
        username,
        content,
        image_url,
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

        // 게시글 저장
        const [result] = await db
            .promise()
            .query(
                'INSERT INTO posts (user_id, content, image_url) VALUES (?, ?, ?)',
                [user[0].user_id, content, image_url || null]
            );

        console.log('Post created:', result); // 디버깅용 로그

        res.status(201).json({
            message: '게시글이 작성되었습니다.',
            post_id: result.insertId,
        });
    } catch (error) {
        console.error('Error creating post:', error);
        res.status(500).json({ message: '게시글 작성에 실패했습니다.' });
    }
});

// 게시글 목록 조회
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

        // 게시글 조회 쿼리 수정
        const [posts] = await db.promise().query(
            `SELECT DISTINCT 
              p.post_id, 
              p.content, 
              p.image_url, 
              p.created_at, 
              u.username
             FROM posts p
             JOIN users u ON p.user_id = u.user_id
             LEFT JOIN relationships r ON u.user_id = r.member_id
             WHERE 
               (u.user_id = ? OR r.leader_id = ?) 
               OR
               (p.user_id IN (SELECT member_id FROM relationships WHERE leader_id = ?))
             ORDER BY p.created_at DESC`,
            [leaderId, leaderId, leaderId]
        );

        // 날짜 포맷 변경 및 이미지, 비디오 URL 확인
        const formattedPosts = posts.map((post) => ({
            ...post,
            created_at: new Date(post.created_at).toLocaleString(),
            image_url: post.image_url ? post.image_url.trim() : null,
            video_url: post.video_url ? post.video_url.trim() : null,
        }));

        res.status(200).json(formattedPosts);
    } catch (error) {
        console.error('Error fetching posts:', error);
        res.status(500).json({
            message: '게시글 목록을 불러오는데 실패했습니다.',
        });
    }
});

// 이미지 업로드 (게시판용)
router.post('/upload', upload.single('image'), (req, res) => {
    if (!req.file) {
        return res.status(400).json({ message: '파일이 없습니다.' });
    }

    const imageUrl = `${process.env.BASE_URL}/uploads/${req.file.filename}`;
    console.log('Generated image URL:', imageUrl);
    res.status(200).json({ url: imageUrl });
});


// 게시글 삭제
router.delete('/:postId', async (req, res) => {
    const { username } = req.body;
    const { postId } = req.params;

    try {
        await db.promise().query('START TRANSACTION');

        const [post] = await db.promise().query(
            `SELECT p.*, u.username, p.image_url
             FROM posts p 
             JOIN users u ON p.user_id = u.user_id 
             WHERE p.post_id = ?`,
            [postId]
        );

        if (post.length === 0) {
            await db.promise().query('ROLLBACK');
            return res
                .status(404)
                .json({ message: '게시글을 찾을 수 없습니다.' });
        }

        if (post[0].username !== username) {
            await db.promise().query('ROLLBACK');
            return res.status(403).json({ message: '삭제 권한이 없습니다.' });
        }

        // 이미지 파일 삭제
        if (post[0].image_url) {
            const imagePath = post[0].image_url.split('/uploads/')[1];
            const fullImagePath = path.join(
                __dirname,
                '..',
                'uploads',
                imagePath
            );
            if (fs.existsSync(fullImagePath)) {
                fs.unlinkSync(fullImagePath);
            }
        }

        // 댓글과 게시글 삭제
        await db
            .promise()
            .query('DELETE FROM comments WHERE post_id = ?', [postId]);
        await db
            .promise()
            .query('DELETE FROM posts WHERE post_id = ?', [postId]);

        await db.promise().query('COMMIT');
        res.status(200).json({ message: '게시글이 삭제되었습니다.' });
    } catch (error) {
        await db.promise().query('ROLLBACK');
        console.error('Error deleting post:', error);
        res.status(500).json({ message: '게시글 삭제에 실패했습니다.' });
    }
});

// 게시글 목록 조회 (댓글 포함)
router.get('/:username', async (req, res) => {
    const { username } = req.params;

    try {
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

        const [posts] = await db.promise().query(
            `SELECT 
                p.*, u.username,
                p.image_url,
                p.video_url,  -- 비디오 URL 추가
                JSON_ARRAYAGG(
                    JSON_OBJECT(
                        'comment_id', c.comment_id,
                        'content', c.content,
                        'username', cu.username,
                        'created_at', c.created_at
                    )
                ) as comments
            FROM posts p
            JOIN users u ON p.user_id = u.user_id
            LEFT JOIN comments c ON p.post_id = c.post_id
            LEFT JOIN users cu ON c.user_id = cu.user_id
            GROUP BY p.post_id
            ORDER BY p.created_at DESC`
        );

        const formattedPosts = posts.map((post) => ({
            ...post,
            created_at: new Date(post.created_at).toLocaleString(),
            image_url: post.image_url ? post.image_url.trim() : null,
            video_url: post.video_url ? post.video_url.trim() : null,
        }));

        res.status(200).json(formattedPosts);
    } catch (error) {
        console.error('Error fetching posts:', error);
        res.status(500).json({
            message: '게시글 목록을 불러오는데 실패했습니다.',
        });
    }
});

module.exports = router;
