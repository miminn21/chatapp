const express  = require('express');
const router   = express.Router();
const ctrl     = require('../controllers/authController');
const authMw   = require('../middleware/auth');

router.post('/firebase-register', ctrl.firebaseRegister);
router.post('/register',          ctrl.register);
router.post('/login',             ctrl.login);
router.post('/logout', authMw,    ctrl.logout);

module.exports = router;
