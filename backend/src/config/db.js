// Store config for logging
let currentConfig = 'unknown';
let pool;

try {
  let dbParams = process.env.MYSQL_URL || {
    host    : process.env.DB_HOST || process.env.MYSQLHOST || 'localhost',
    user    : process.env.DB_USER || process.env.MYSQLUSER || 'root',
    password: process.env.DB_PASS || process.env.DB_PASSWORD || process.env.MYSQLPASSWORD || '',
    database: process.env.DB_NAME || process.env.MYSQLDATABASE || 'railway',
    port    : parseInt(process.env.DB_PORT || process.env.MYSQLPORT || 3306),
    connectionLimit: 10,
    connectTimeout: 30000,
    bigIntAsNumber : true,
  };

  if (typeof dbParams === 'string') {
    // Railway provides 'mysql://', but some drivers/versions of MariaDB node client 
    // strictly want 'mariadb://'. Let's ensure it's compatible.
    if (dbParams.startsWith('mysql://')) {
      dbParams = dbParams.replace('mysql://', 'mariadb://');
    }
    currentConfig = 'MYSQL_URL';
    console.log('🔗 Database: Using converted MYSQL_URL');
  } else {
    currentConfig = `host=${dbParams.host}, db=${dbParams.database}`;
    console.log(`🔌 Database: Using individual variables (${currentConfig})`);
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
      console.log(`🔌 DB First Query: ${currentConfig}`);
      global.dbLogged = true;
    }
    if (!pool) throw new Error('Database pool not initialized');
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
