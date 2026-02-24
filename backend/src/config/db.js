const mariadb = require('mariadb');

const dbConfig = {
  host    : process.env.DB_HOST || process.env.MYSQLHOST || 'localhost',
  user    : process.env.DB_USER || process.env.MYSQLUSER || 'root',
  password: process.env.DB_PASS || process.env.DB_PASSWORD || process.env.MYSQLPASSWORD || '',
  database: process.env.DB_NAME || process.env.MYSQLDATABASE || 'railway',
  port    : parseInt(process.env.DB_PORT || process.env.MYSQLPORT || 3306),
  connectionLimit: 10,
  connectTimeout: 20000, // 20 seconds
  acquireTimeout: 20000, // 20 seconds
  bigIntAsNumber : true,
};

const pool = mariadb.createPool(dbConfig);

async function query(sql, params = []) {
  let conn;
  try {
    // Log connection details ONLY for the very first query to help diagnostics
    if (!global.dbLogged) {
      console.log(`🔌 DB Connection Config: host=${dbConfig.host}, port=${dbConfig.port}, user=${dbConfig.user}, db=${dbConfig.database}`);
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
