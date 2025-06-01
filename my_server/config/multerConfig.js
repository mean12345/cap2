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

const dogsstorage = multer.diskStorage({
    destination: function (req, file, cb) {
        cb(null, 'dogs_profile/');
    },
    filename: function (req, file, cb) {
        cb(null, Date.now() + '-' + file.originalname);
    },
});


module.exports = {
    upload: multer({ storage: storage }),
    profilestorage: multer({ storage: profilestorage }),
    dogsstorage: multer({ storage: dogsstorage }),
};
