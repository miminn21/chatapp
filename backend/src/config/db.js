const mariadb = require('mariadb');

// Store config for logging
let currentConfig = 'unknown';

try {
  if (process.env.MYSQL_URL) {
    currentConfig = 'MYSQL_URL (Internal)';
    pool = mariadb.createPool(process.env.MYSQL_URL);
    console.log('🔗 Database: Using MYSQL_URL');
  } else {
    const dbParams = {
      host    : process.env.DB_HOST || process.env.MYSQLHOST || 'localhost',
      user    : process.env.DB_USER || process.env.MYSQLUSER || 'root',
      password: process.env.DB_PASS || process.env.DB_PASSWORD || process.env.MYSQLPASSWORD || '',
      database: process.env.DB_NAME || process.env.MYSQLDATABASE || 'railway',
      port    : parseInt(process.env.DB_PORT || process.env.MYSQLPORT || 3306),
      connectionLimit: 10,
      connectTimeout: 30000,
      bigIntAsNumber : true,
    };
    currentConfig = `host=${dbParams.host}, db=${dbParams.database}`;
    pool = mariadb.createPool(dbParams);
    console.log(`🔌 Database: Using individual variables (${currentConfig})`);
  }
} catch (err) {
  console.error('❌ Failed to create MariaDB pool:', err.message);
}

async function query(sql, params = []) {
  let conn;
  try {
    if (!global.dbLogged) {
      console.log(`🔌 First Query Attempt using: ${currentConfig}`);
      global.dbLogged = true;
    }
    conn = await pool.getConnection();
    return await conn.query(sql, params);
  } catch (err) {
    console.error(`❌ DB Query Error: ${err.message}`);
    throw err;
  } finally {
    if (conn) conn.release();
  }
}

module.exports = { query, pool };
