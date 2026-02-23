const express = require('express');
const router  = express.Router();
const ctrl    = require('../controllers/groupController');
const authMw  = require('../middleware/auth');
const { memoryUpload: upload } = require('../middleware/upload');

router.use(authMw);

router.post('/',                                    ctrl.createGroup);
router.get('/:conversation_id',                     ctrl.getGroupInfo);
router.put('/:conversation_id',                     ctrl.updateGroup);
router.delete('/:conversation_id',                  ctrl.deleteGroup);
router.post('/:conversation_id/avatar', upload.single('avatar'), ctrl.uploadGroupAvatar);
router.post('/:conversation_id/members',            ctrl.addMember);
router.delete('/:conversation_id/members/:user_id', ctrl.removeMember);

module.exports = router;
