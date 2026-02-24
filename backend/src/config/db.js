const mariadb = require('mariadb');
const { URL } = require('url');

// Global state for logging
global.dbLogged = false;

let pool;
let currentConfigDesc = 'not-set';

try {
  let dbConfig;

  if (process.env.MYSQL_URL) {
    const urlString = process.env.MYSQL_URL;
    try {
      // Manual parsing to be safe and cross-compatible
      const parsed = new URL(urlString);
      dbConfig = {
        host: parsed.hostname,
        port: parseInt(parsed.port) || 3306,
        user: parsed.username,
        password: decodeURIComponent(parsed.password),
        database: parsed.pathname.substring(1), // Remove leading slash
        connectionLimit: 10,
        connectTimeout: 30000,
        bigIntAsNumber : true,
      };
      currentConfigDesc = `MYSQL_URL (${dbConfig.host})`;
      console.log(`🔗 Database: Successfully parsed MYSQL_URL for host ${dbConfig.host}`);
    } catch (parseErr) {
      console.error('⚠️ Failed to parse MYSQL_URL, falling back to individual variables:', parseErr.message);
      // Fallback below
    }
  }

  if (!dbConfig) {
    dbConfig = {
      host: process.env.DB_HOST || process.env.MYSQLHOST || 'localhost',
      user: process.env.DB_USER || process.env.MYSQLUSER || 'root',
      password: process.env.DB_PASS || process.env.DB_PASSWORD || process.env.MYSQLPASSWORD || '',
      database: process.env.DB_NAME || process.env.MYSQLDATABASE || 'railway',
      port: parseInt(process.env.DB_PORT || process.env.MYSQLPORT || 3306),
      connectionLimit: 10,
      connectTimeout: 30000,
      bigIntAsNumber : true,
    };
    currentConfigDesc = `Variables (${dbConfig.host})`;
    console.log(`🔌 Database: Using individual variables for host ${dbConfig.host}`);
  }

  pool = mariadb.createPool(dbConfig);
} catch (err) {
  console.error('❌ FATAL: Failed to initialize database pool:', err.message);
}

const dns = require('dns');

// Execute DNS lookup for diagnostic
dns.lookup('mysql.railway.internal', (err, address) => {
  console.log('🔍 DNS Diagnostics: mysql.railway.internal resolves to ->', address || 'FAILED', err ? `(${err.message})` : '');
});

/**
 * Execute SQL queries
 */
async function query(sql, params = []) {
  if (!pool) {
    throw new Error('Database pool not initialized.');
  }

  let conn;
  try {
    if (!global.dbLogged) {
      console.log(`🚀 [QUERY START] Mode: ${currentConfigDesc}`);
      global.dbLogged = true;
    }
    
    console.log(`⏳ [STEP 1] Requesting connection from pool...`);
    conn = await pool.getConnection();
    console.log(`✅ [STEP 2] Connection obtained.`);
    
    console.log(`⏳ [STEP 3] Running query: ${sql.substring(0, 30)}...`);
    const results = await conn.query(sql, params);
    console.log(`✅ [STEP 4] Query successful.`);
    
    return results;
  } catch (err) {
    console.error(`❌ Database Error at ${sql.substring(0, 20)}: ${err.message}`);
    throw err;
  } finally {
    if (conn) {
      console.log(`🔌 [STEP 5] Releasing connection back to pool.`);
      conn.release();
    }
  }
}

module.exports = { query, pool };
