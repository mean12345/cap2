const express = require('express');
const router = express.Router();
const bcrypt = require('bcrypt');
const db = require('../config/database');
const {
    generateVerificationCode,
    sendEmail,
} = require('../utils/emailService');

//이메일 인증 코드 발송
router.post('/send-verification-email', (req, res) => {
    const { email } = req.body;
    console.log('Received request to send verification email to:', email);

    // 먼저 해당 이메일이 users 테이블에 존재하는지 확인
    db.query('SELECT * FROM users WHERE email = ?', [email], (err, users) => {
        if (err) {
            console.error('Database error:', err);
            return res.status(500).json({
                success: false,
                message: '데이터베이스 오류가 발생했습니다.',
            });
        }

        if (!users.length) {
            return res.status(404).json({
                success: false,
                message: '등록되지 않은 이메일입니다.',
            });
        }

        const verificationCode = generateVerificationCode();
        const expiresAt = new Date(Date.now() + 2 * 60 * 1000); // 2분 후 만료

        // 이전 인증 코드가 있다면 만료 처리
        db.query(
            'UPDATE email_verification SET is_verified = TRUE WHERE email = ? AND is_verified = FALSE',
            [email],
            (err) => {
                if (err) {
                    console.error(
                        'Error updating previous verification codes:',
                        err
                    );
                    return res.status(500).json({
                        success: false,
                        message: '이전 인증 코드 처리 중 오류가 발생했습니다.',
                    });
                }

                // 새 인증 코드 저장
                db.query(
                    'INSERT INTO email_verification (email, verification_code, expires_at) VALUES (?, ?, ?)',
                    [email, verificationCode, expiresAt],
                    (err) => {
                        if (err) {
                            console.error(
                                'Error inserting verification code:',
                                err
                            );
                            return res.status(500).json({
                                success: false,
                                message:
                                    '인증 코드 저장 중 오류가 발생했습니다.',
                            });
                        }

                        // 이메일 발송
                        sendEmail(email, verificationCode)
                            .then(() => {
                                res.status(200).json({
                                    success: true,
                                    message: '인증 코드가 발송되었습니다.',
                                });
                            })
                            .catch((err) => {
                                console.error('Error sending email:', err);
                                res.status(500).json({
                                    success: false,
                                    message:
                                        '이메일 발송 중 오류가 발생했습니다.',
                                });
                            });
                    }
                );
            }
        );
    });
});

//이메일 인증 코드 검증
router.post('/verify-code', (req, res) => {
    const { email, code } = req.body;
    console.log('Verifying code for email:', email);

    // 가장 최근의 인증 코드 조회 <-- 변경 필요
    db.query(
        'SELECT * FROM email_verification WHERE email = ? AND is_verified = FALSE ORDER BY created_at DESC LIMIT 1',
        [email],
        (err, result) => {
            if (err) {
                console.error('Database error:', err);
                return res.status(500).json({
                    success: false,
                    message: '데이터베이스 오류가 발생했습니다.',
                });
            }

            if (!result.length) {
                return res.status(400).json({
                    success: false,
                    message: '유효한 인증 코드를 찾을 수 없습니다.',
                });
            }

            const verificationRecord = result[0];

            // 만료 시간 확인
            if (new Date(verificationRecord.expires_at) < new Date()) {
                return res.status(400).json({
                    success: false,
                    message: '인증 코드가 만료되었습니다.',
                });
            }

            // 코드 일치 확인
            if (verificationRecord.verification_code !== code) {
                return res.status(400).json({
                    success: false,
                    message: '잘못된 인증 코드입니다.',
                });
            }

            // 인증 완료 처리
            db.query(
                'UPDATE email_verification SET is_verified = TRUE WHERE verification_id = ?',
                [verificationRecord.verification_id],
                (err) => {
                    if (err) {
                        console.error(
                            'Error updating verification status:',
                            err
                        );
                        return res.status(500).json({
                            success: false,
                            message:
                                '인증 상태 업데이트 중 오류가 발생했습니다.',
                        });
                    }

                    res.status(200).json({
                        success: true,
                        message: '인증이 완료되었습니다.',
                    });
                }
            );
        }
    );
});

//비밀번호 재설정
router.post('/reset-password', async (req, res) => {
    const { username, password } = req.body;

    if (!username || !password) {
        return res
            .status(400)
            .json({ message: '아이디와 비밀번호를 모두 입력해주세요.' });
    }

    // 비밀번호 해싱
    const hashedPassword = await bcrypt.hash(password, 10);

    // MySQL 쿼리로 사용자 찾기
    const query = 'UPDATE users SET password = ? WHERE username = ?';
    db.query(query, [hashedPassword, username], (err, result) => {
        if (err) {
            console.error('비밀번호 업데이트 오류:', err);
            return res
                .status(500)
                .json({ message: '서버 오류가 발생했습니다.' });
        }

        if (result.affectedRows === 0) {
            return res
                .status(404)
                .json({ message: '사용자를 찾을 수 없습니다.' });
        }

        return res
            .status(200)
            .json({ message: '비밀번호가 성공적으로 재설정되었습니다.' });
    });
});

//아이디 찾기
router.post('/find-id', (req, res) => {
    const { email } = req.body;
    console.log('Finding ID for email:', email);

    // 이메일 인증 여부 확인
    db.query(
        'SELECT * FROM email_verification WHERE email = ? AND is_verified = TRUE ORDER BY created_at DESC LIMIT 1',
        [email],
        (err, verificationResult) => {
            if (err) {
                console.error('Database error:', err);
                return res.status(500).json({
                    success: false,
                    message: '데이터베이스 오류가 발생했습니다.',
                });
            }

            if (!verificationResult.length) {
                return res.status(400).json({
                    success: false,
                    message: '이메일 인증이 완료되지 않았습니다.',
                });
            }

            // 사용자 아이디 조회
            db.query(
                'SELECT username FROM users WHERE email = ?',
                [email],
                (err, userResult) => {
                    if (err) {
                        console.error('Database error:', err);
                        return res.status(500).json({
                            success: false,
                            message: '데이터베이스 오류가 발생했습니다.',
                        });
                    }

                    if (!userResult.length) {
                        return res.status(404).json({
                            success: false,
                            message: '등록된 아이디를 찾을 수 없습니다.',
                        });
                    }

                    res.status(200).json({
                        success: true,
                        user_id: userResult[0].username,
                    });
                }
            );
        }
    );
});

module.exports = router;
