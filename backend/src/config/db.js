const mysql = require('mysql2/promise');

// Global state for logging
global.dbLogged = false;

let pool;
let currentConfigDesc = 'not-set';

async function initPool() {
  if (pool) return pool;

  try {
    let dbConfig;

    if (process.env.MYSQL_URL) {
      // mysql2 supports connection strings directly with some options
      dbConfig = process.env.MYSQL_URL;
      currentConfigDesc = 'MYSQL_URL';
      
      // Convert mysql:// to mariadb:// is NOT needed for mysql2
      // Just ensure we have common options
      pool = mysql.createPool({
        uri: dbConfig,
        connectionLimit: 10,
        waitForConnections: true,
        queueLimit: 0,
        enableKeepAlive: true,
        keepAliveInitialDelay: 0
      });
      console.log('🔗 Database: Pool created using MYSQL_URL');
    } else {
      dbConfig = {
        host: process.env.DB_HOST || process.env.MYSQLHOST || 'localhost',
        user: process.env.DB_USER || process.env.MYSQLUSER || 'root',
        password: process.env.DB_PASS || process.env.DB_PASSWORD || process.env.MYSQLPASSWORD || '',
        database: process.env.DB_NAME || process.env.MYSQLDATABASE || 'railway',
        port: parseInt(process.env.DB_PORT || process.env.MYSQLPORT || 3306),
        connectionLimit: 10,
        waitForConnections: true,
        queueLimit: 0
      };
      currentConfigDesc = `Variables (${dbConfig.host})`;
      pool = mysql.createPool(dbConfig);
      console.log(`🔌 Database: Pool created using individual variables (${dbConfig.host})`);
    }

    return pool;
  } catch (err) {
    console.error('❌ FATAL: Failed to initialize MySQL pool:', err.message);
    throw err;
  }
}

/**
 * Execute SQL queries
 */
async function query(sql, params = []) {
  try {
    if (!pool) {
      await initPool();
    }

    if (!global.dbLogged) {
      console.log(`🚀 [QUERY START] Mode: ${currentConfigDesc}`);
      global.dbLogged = true;
    }

    // Using pool.execute for prepared statements (security + performance)
    const [results] = await pool.execute(sql, params);
    return results;
  } catch (err) {
    console.error(`❌ Database Error: ${err.message}`);
    throw err;
  }
}

module.exports = { query, initPool };
