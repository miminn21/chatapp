const admin = require('firebase-admin');
const path  = require('path');

let _admin = null;

function getAdmin() {
  if (_admin) return _admin;
  
  try {
    let sa;
    // 1. Try environment variable (stringified JSON)
    if (process.env.FIREBASE_SERVICE_ACCOUNT) {
      sa = JSON.parse(process.env.FIREBASE_SERVICE_ACCOUNT);
    } else {
      // 2. Try local file (development only)
      const p = path.resolve(__dirname, '../../firebase-service-account.json');
      if (require('fs').existsSync(p)) {
        sa = require(p);
      } else {
        console.warn('⚠️ FIREBASE_SERVICE_ACCOUNT env var is missing and local JSON file not found.');
        return null;
      }
    }

    if (!admin.apps.length) {
      admin.initializeApp({
        credential: admin.credential.cert(sa)
      });
      console.log('✅ Firebase Admin SDK initialized');
    }
    _admin = admin;
  } catch (e) {
    console.error('❌ Firebase Admin init failed:', e.message);
  }
  return _admin;
}

module.exports = getAdmin();
