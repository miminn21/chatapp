const express  = require('express');
const router   = express.Router();
const convCtrl = require('../controllers/conversationController');
const msgCtrl  = require('../controllers/messageController');
const authMw   = require('../middleware/auth');
const { upload } = require('../middleware/upload');

router.use(authMw);

router.get('/',          convCtrl.getConversations);
router.post('/dm',       convCtrl.createOrGetDM);
router.get('/:id',       convCtrl.getConversation);
router.get('/:id/members', convCtrl.getMembers);

router.get('/:id/messages',  msgCtrl.getMessages);
router.post('/:id/messages', upload.single('file'), msgCtrl.sendMessage);

module.exports = router;
