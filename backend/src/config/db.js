const mariadb = require('mariadb');

// Use MYSQL_URL if available, otherwise fallback to individual variables
const dbConfig = process.env.MYSQL_URL || {
  host    : process.env.DB_HOST || process.env.MYSQLHOST || 'localhost',
  user    : process.env.DB_USER || process.env.MYSQLUSER || 'root',
  password: process.env.DB_PASS || process.env.DB_PASSWORD || process.env.MYSQLPASSWORD || '',
  database: process.env.DB_NAME || process.env.MYSQLDATABASE || 'railway',
  port    : parseInt(process.env.DB_PORT || process.env.MYSQLPORT || 3306),
};

// Add common pool options
const poolOptions = {
  ...((typeof dbConfig === 'string') ? { connectionString: dbConfig } : dbConfig),
  connectionLimit: 10,
  connectTimeout: 30000, // Increased to 30 seconds
  acquireTimeout: 30000,
  bigIntAsNumber : true,
};

const pool = mariadb.createPool(poolOptions);

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
