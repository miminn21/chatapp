const express = require('express');
const router  = express.Router();
const ctrl    = require('../controllers/userController');
const authMw  = require('../middleware/auth');
const { memoryUpload: upload } = require('../middleware/upload');

router.use(authMw);

router.get('/me',          ctrl.getMe);
router.put('/me',          ctrl.updateMe);
router.post('/me/avatar',  upload.single('avatar'), ctrl.uploadAvatar);
router.post('/me/cover',   upload.single('cover'),  ctrl.uploadCover);
router.post('/me/fcm-token', ctrl.updateFcmToken);
router.get('/search',      ctrl.searchUsers);
router.get('/:id',         ctrl.getUser);

module.exports = router;
