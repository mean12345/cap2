const express = require('express');
const router = express.Router();
const db = require('../config/database');
const { dogsstorage } = require('../config/multerConfig');
const path = require('path');
const fs = require('fs');


// 강아지 프로필 추가
router.post('/', async (req, res) => {
    const { username, dog_name, image_url } = req.body;

    console.log('Received dog profile data:', {
        username,
        dog_name,
        image_url,
    }); // 디버깅용 로그

    if (!username || !dog_name) {
        return res.status(400).json({ message: 'username과 dog_name은 필수입니다.' });
    }

    try {
        // 사용자 ID와 역할 조회
        const [userRows] = await db
            .promise()
            .query('SELECT user_id, role FROM users WHERE username = ?', [username]);

        if (userRows.length === 0) {
            return res.status(404).json({ message: '사용자를 찾을 수 없습니다.' });
        }

        const { user_id, role } = userRows[0];

        let leader_id;

        if (role === 'leader') {
            leader_id = user_id;
        } else {
            // 멤버인 경우 relationships 테이블에서 leader_id 조회
            const [relRows] = await db
                .promise()
                .query('SELECT leader_id FROM relationships WHERE member_id = ?', [user_id]);

            if (relRows.length === 0) {
                return res.status(403).json({ message: '리더와 연결된 멤버가 아닙니다.' });
            }

            leader_id = relRows[0].leader_id;
        }

        // 강아지 프로필 등록
        const [result] = await db
            .promise()
            .query(
                'INSERT INTO dogs (leader_id, dog_name, image_url) VALUES (?, ?, ?)',
                [leader_id, dog_name, image_url || null]
            );

        console.log('Dog profile created:', result); // 디버깅용 로그

        res.status(201).json({
            message: '강아지 프로필이 등록되었습니다.',
            dog_id: result.insertId,
        });
    } catch (error) {
        console.error('강아지 등록 오류:', error);
        res.status(500).json({ message: '강아지 등록에 실패했습니다.' });
    }
});

// 강아지 프로필 수정
router.put('/update/:dog_id', async (req, res) => {
    const { dog_id } = req.params;
    const { dog_name, image_url } = req.body;

    if (!dog_name && !image_url) {
        return res.status(400).json({ message: '수정할 dog_name 또는 image_url 중 하나는 필요합니다.' });
    }

    try {
        // 먼저 해당 dog_id가 존재하는지 확인
        const [dogRows] = await db.promise().query(
            'SELECT * FROM dogs WHERE dog_id = ?',
            [dog_id]
        );

        if (dogRows.length === 0) {
            return res.status(404).json({ message: '강아지 프로필을 찾을 수 없습니다.' });
        }

        // 변경할 필드를 동적으로 구성
        const fields = [];
        const values = [];

        if (dog_name) {
            fields.push('dog_name = ?');
            values.push(dog_name);
        }
        if (image_url) {
            fields.push('image_url = ?');
            values.push(image_url);
        }

        values.push(dog_id); // WHERE절에 쓸 dog_id

        const updateQuery = `UPDATE dogs SET ${fields.join(', ')} WHERE dog_id = ?`;

        const [result] = await db.promise().query(updateQuery, values);

        res.status(200).json({
            message: '강아지 프로필이 성공적으로 수정되었습니다.',
            updatedFields: { dog_name, image_url }
        });
    } catch (error) {
        console.error('강아지 수정 오류:', error);
        res.status(500).json({ message: '강아지 수정에 실패했습니다.' });
    }
});


router.post('/dogs_profile', dogsstorage.single('image'), (req, res) => {
    if (!req.file) {
        return res.status(400).json({ message: '파일이 없습니다.' });
    }

    const imageUrl = `${process.env.BASE_URL}/dogs_profile/${req.file.filename}`;
    console.log('Generated image URL:', imageUrl);
    res.status(200).json({ url: imageUrl });
});


router.get('/get_dogs', async (req, res) => {
    const username = req.query.username;  // 제대로 받아옴
    console.log('Received username:', username);

    if (!username) {
        return res.status(400).send({ message: '사용자 이름이 제공되지 않았습니다.' });
    }

    try {
        const [userRows] = await db.promise().query(
            'SELECT user_id, role FROM users WHERE username = ?',
            [username]
        );

        if (userRows.length === 0) {
            return res.status(404).send({ message: '사용자를 찾을 수 없습니다.' });
        }

        const { user_id, role } = userRows[0];
        let leader_id;

        if (role === 'leader') {
            leader_id = user_id;
        } else {
            const [relRows] = await db.promise().query(
                'SELECT leader_id FROM relationships WHERE member_id = ?',
                [user_id]
            );

            if (relRows.length === 0) {
                return res.status(404).send({ message: '리더와 연결된 멤버가 아닙니다.' });
            }

            leader_id = relRows[0].leader_id;
        }

        // 여러 마리 강아지를 가져옴
        const [dogs] = await db.promise().query(
            'SELECT * FROM dogs WHERE leader_id = ?',
            [leader_id]
        );

        if (dogs.length === 0) {
            return res.status(404).send({ message: '강아지 정보가 없습니다.' });
        }

        // 강아지 리스트 포맷
        const dogProfiles = dogs.map(dog => ({
            id: dog.dog_id,  // dog_id 사용
            name: dog.dog_name,  // dog_name 사용
            imageUrl: dog.image_url  // image_url 사용
        }));

        res.status(200).send(dogProfiles); // 리스트로 보냄

    } catch (err) {
        console.error('강아지 조회 오류:', err);
        res.status(500).send({ message: '서버 오류가 발생했습니다.' });
    }
});


router.delete('/:dog_id', (req, res) => {
  const { dog_id } = req.params;

  db.query('DELETE FROM dogs WHERE dog_id = ?', [dog_id], (err, result) => {
      if (err) return res.status(500).send({ message: '삭제 실패' });
      if (result.affectedRows === 0) return res.status(404).send({ message: '강아지를 찾을 수 없음' });
      res.status(200).send({ message: '강아지 프로필 삭제됨' });
  });
});

module.exports = router;
