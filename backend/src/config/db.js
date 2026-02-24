const mariadb = require('mariadb');

let pool;

try {
  let dbParams;
  
  if (process.env.MYSQL_URL) {
    // If we have a full URL, use it directly (Mariadb createPool supports URI)
    dbParams = process.env.MYSQL_URL;
    console.log('🔗 Using MYSQL_URL for database connection');
  } else {
    // Fallback to individual variables
    dbParams = {
      host    : process.env.DB_HOST || process.env.MYSQLHOST || 'localhost',
      user    : process.env.DB_USER || process.env.MYSQLUSER || 'root',
      password: process.env.DB_PASS || process.env.DB_PASSWORD || process.env.MYSQLPASSWORD || '',
      database: process.env.DB_NAME || process.env.MYSQLDATABASE || 'railway',
      port    : parseInt(process.env.DB_PORT || process.env.MYSQLPORT || 3306),
      connectionLimit: 10,
      connectTimeout: 30000,
      bigIntAsNumber : true,
    };
    console.log(`🔌 Using individual variables: host=${dbParams.host}, db=${dbParams.database}`);
  }

  pool = mariadb.createPool(dbParams);
} catch (err) {
  console.error('❌ Failed to create MariaDB pool:', err.message);
}

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
