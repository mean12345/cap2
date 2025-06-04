const express = require('express');
const router = express.Router();
const db = require('../config/database');
const path = require('path');
const fs = require('fs');

// 리더가 멤버 삭제
router.delete('/member/:memberUsername', async (req, res) => {
    const { username } = req.body;

    try {
        const [leader] = await db
            .promise()
            .query('SELECT user_id, role FROM users WHERE username = ?', [
                username,
            ]);

        if (leader.length === 0 || leader[0].role !== 'leader') {
            return res.status(403).json({ message: '권한이 없습니다.' });
        }

        const [member] = await db
            .promise()
            .query('SELECT user_id FROM users WHERE username = ?', [
                req.params.memberUsername,
            ]);

        if (member.length === 0) {
            return res
                .status(404)
                .json({ message: '멤버를 찾을 수 없습니다.' });
        }

        await db.promise().query('START TRANSACTION');

        const [posts] = await db
            .promise()
            .query('SELECT image_url FROM posts WHERE user_id = ?', [
                member[0].user_id,
            ]);

        for (const post of posts) {
            if (post.image_url) {
                const imagePath = post.image_url.split('/uploads/')[1];
                const fullPath = path.join(
                    __dirname,
                    '..',
                    'uploads',
                    imagePath
                );
                if (fs.existsSync(fullPath)) {
                    fs.unlinkSync(fullPath);
                }
            }
        }

        await db
            .promise()
            .query('DELETE FROM posts WHERE user_id = ?', [member[0].user_id]);
        await db
            .promise()
            .query(
                'DELETE FROM relationships WHERE leader_id = ? AND member_id = ?',
                [leader[0].user_id, member[0].user_id]
            );
        await db
            .promise()
            .query('UPDATE users SET role = "leader" WHERE user_id = ?', [
                member[0].user_id,
            ]);

        await db.promise().query('COMMIT');
        res.status(200).json({ message: '멤버가 삭제되었습니다.' });
    } catch (error) {
        await db.promise().query('ROLLBACK');
        console.error('Error removing member:', error);
        res.status(500).json({ message: '멤버 삭제에 실패했습니다.' });
    }
});

// 멤버 탈퇴
router.delete('/leave', async (req, res) => {
    const { username } = req.body;
    console.log('Attempting to leave relationship for user:', username);

    try {
        const [member] = await db
            .promise()
            .query('SELECT user_id, role FROM users WHERE username = ?', [
                username,
            ]);

        if (member.length === 0) {
            return res
                .status(404)
                .json({ message: '사용자를 찾을 수 없습니다.' });
        }

        if (member[0].role !== 'member') {
            return res
                .status(403)
                .json({ message: '멤버만 탈퇴할 수 있습니다.' });
        }

        await db.promise().query('START TRANSACTION');

        try {
            await db
                .promise()
                .query('DELETE FROM comments WHERE user_id = ?', [
                    member[0].user_id,
                ]);

            const [posts] = await db
                .promise()
                .query('SELECT post_id FROM posts WHERE user_id = ?', [
                    member[0].user_id,
                ]);

            for (const post of posts) {
                await db
                    .promise()
                    .query('DELETE FROM comments WHERE post_id = ?', [
                        post.post_id,
                    ]);
            }

            await db
                .promise()
                .query('DELETE FROM posts WHERE user_id = ?', [
                    member[0].user_id,
                ]);
            await db
                .promise()
                .query('DELETE FROM photos WHERE user_id = ?', [
                    member[0].user_id,
                ]);
            await db
                .promise()
                .query('DELETE FROM relationships WHERE member_id = ?', [
                    member[0].user_id,
                ]);
            await db
                .promise()
                .query('UPDATE users SET role = "leader" WHERE user_id = ?', [
                    member[0].user_id,
                ]);

            await db.promise().query('COMMIT');
            res.status(200).json({ message: '탈퇴가 완료되었습니다.' });
        } catch (error) {
            console.error('Error during transaction:', error);
            await db.promise().query('ROLLBACK');
            throw error;
        }
    } catch (error) {
        console.error('Error in leave relationship:', error);
        res.status(500).json({
            message: '탈퇴에 실패했습니다.',
            error: error.message,
        });
    }
});

module.exports = router;
