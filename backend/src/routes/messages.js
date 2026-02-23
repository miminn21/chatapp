const express = require('express');
const router  = express.Router();
const ctrl    = require('../controllers/messageController');
const authMw  = require('../middleware/auth');

router.use(authMw);

router.patch('/:id', ctrl.editMessage);
router.delete('/:id', ctrl.deleteMessage);

module.exports = router;
