const express = require('express');
const router = express.Router();
const db = require('../config/database');

// 댓글 작성
router.post('/', async (req, res) => {
    const { post_id, username, content } = req.body;

    try {
        const [user] = await db
            .promise()
            .query('SELECT user_id FROM users WHERE username = ?', [username]);

        if (user.length === 0) {
            return res
                .status(404)
                .json({ message: '사용자를 찾을 수 없습니다.' });
        }

        await db
            .promise()
            .query(
                'INSERT INTO comments (post_id, user_id, content) VALUES (?, ?, ?)',
                [post_id, user[0].user_id, content]
            );

        res.status(201).json({ message: '댓글이 작성되었습니다.' });
    } catch (error) {
        console.error('Error creating comment:', error);
        res.status(500).json({ message: '댓글 작성에 실패했습니다.' });
    }
});

// 게시글의 댓글 목록 조회
router.get('/posts/:postId', async (req, res) => {
    const { postId } = req.params;

    try {
        const [comments] = await db.promise().query(
            `SELECT 
                c.comment_id,
                c.content,
                c.created_at,
                u.username
              FROM comments c
              JOIN users u ON c.user_id = u.user_id
              WHERE c.post_id = ?
              ORDER BY c.created_at ASC`,
            [postId]
        );

        const formattedComments = comments.map((comment) => ({
            ...comment,
            created_at: new Date(comment.created_at).toLocaleString(),
        }));

        res.status(200).json(formattedComments);
    } catch (error) {
        console.error('Error fetching comments:', error);
        res.status(500).json({
            message: '댓글 목록을 불러오는데 실패했습니다.',
        });
    }
});

// 댓글 삭제
router.delete('/:commentId', async (req, res) => {
    const { username } = req.body;
    const { commentId } = req.params;

    try {
        const [comment] = await db.promise().query(
            `SELECT c.*, u.username 
             FROM comments c 
             JOIN users u ON c.user_id = u.user_id 
             WHERE c.comment_id = ?`,
            [commentId]
        );

        if (comment.length === 0) {
            return res
                .status(404)
                .json({ message: '댓글을 찾을 수 없습니다.' });
        }

        if (comment[0].username !== username) {
            return res.status(403).json({ message: '삭제 권한이 없습니다.' });
        }

        await db
            .promise()
            .query('DELETE FROM comments WHERE comment_id = ?', [commentId]);

        res.status(200).json({ message: '댓글이 삭제되었습니다.' });
    } catch (error) {
        console.error('Error deleting comment:', error);
        res.status(500).json({ message: '댓글 삭제에 실패했습니다.' });
    }
});

module.exports = router;
