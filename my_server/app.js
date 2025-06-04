const express = require('express');
const cors = require('cors');
require('dotenv').config();
const db = require('./config/database');
const https = require('https');

const authRoutes = require('./routes/auth');
const userRoutes = require('./routes/users');
const markerRoutes = require('./routes/markers');
const trackingRoutes = require('./routes/tracking');
const postRoutes = require('./routes/posts');
const connectionRoutes = require('./routes/connections');
const commentsRouter = require('./routes/comments');
const relationshipsRouter = require('./routes/relationships');
const calendarRoutes = require('./routes/calendar');
const dogRoutes = require('./routes/dog');
const navigationRouter = require('./routes/navigation');
const app = express();

app.use(cors());
app.use(express.json());

// 라우트 등록
app.use('/auth', authRoutes);
app.use('/users', userRoutes);
app.use('/markers', markerRoutes);
app.use('/tracking', trackingRoutes);
app.use('/posts', postRoutes);
app.use('/', connectionRoutes);
app.use('/comments', commentsRouter);
app.use('/relationships', relationshipsRouter);
app.use('/calendar', calendarRoutes);
app.use('/dogs', dogRoutes);
app.use('/direction', navigationRouter);

// 정적 파일 제공
app.use('/uploads', express.static('uploads'));
app.use('/profile_uploads', express.static('profile_uploads'));
app.use('/dogs_profile', express.static('dogs_profile'));

// 만료된 초대 코드 자동 삭제 스케줄러
const cleanupExpiredCodes = async () => {
    try {
        await db
            .promise()
            .query('DELETE FROM connection_codes WHERE expires_at <= NOW()');
    } catch (error) {
        console.error('Error cleaning up expired codes:', error);
    }
};

// 만료된 이메일 인증 코드 자동 삭제 스케줄러
const cleanupExpiredEmailCodes = async () => {
    try {
        await db
            .promise()
            .query('DELETE FROM email_verification WHERE expires_at <= NOW()');
    } catch (error) {
        console.error(
            'Error cleaning up expired email verification codes:',
            error
        );
    }
};

setInterval(cleanupExpiredEmailCodes, 60000);
setInterval(cleanupExpiredCodes, 60000);

app.use((err, req, res, next) => {
    console.error('Error details:', {
        path: req.path,
        method: req.method,
        body: req.body,
        error: err.message,
        stack: err.stack,
    });

    res.status(500).json({
        message: 'Internal Server Error',
        error: err.message,
    });
});
module.exports = app;
