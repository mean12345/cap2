const multer = require('multer');

const storage = multer.diskStorage({
    destination: function (req, file, cb) {
        cb(null, 'uploads/');
    },
    filename: function (req, file, cb) {
        cb(null, Date.now() + '-' + file.originalname);
    },
});

const profilestorage = multer.diskStorage({
    destination: function (req, file, cb) {
        cb(null, 'profile_uploads/');
    },
    filename: function (req, file, cb) {
        cb(null, Date.now() + '-' + file.originalname);
    },
});

const photoStorage = multer.diskStorage({
    destination: function (req, file, cb) {
        cb(null, 'photo_share/');
    },
    filename: function (req, file, cb) {
        cb(null, Date.now() + '-' + file.originalname);
    },
});

const videoStorage = multer.diskStorage({
    destination: function (req, file, cb) {
        cb(null, 'video_share/');
    },
    filename: function (req, file, cb) {
        cb(null, Date.now() + '-' + file.originalname);
    },
});

module.exports = {
    upload: multer({ storage: storage }),
    profilestorage: multer({ storage: profilestorage }),
    photoUpload: multer({ storage: photoStorage }),
    uploadVideo: multer({ storage: videoStorage }),
};
