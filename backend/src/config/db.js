const mariadb = require('mariadb');

const pool = mariadb.createPool({
  host    : process.env.DB_HOST || process.env.MYSQLHOST || 'localhost',
  user    : process.env.DB_USER || process.env.MYSQLUSER || 'root',
  password: process.env.DB_PASS || process.env.DB_PASSWORD || process.env.MYSQLPASSWORD || '',
  database: process.env.DB_NAME || process.env.MYSQLDATABASE || 'chatapp_db',
  port    : process.env.DB_PORT || process.env.MYSQLPORT || 3306,
  connectionLimit: 10,
  bigIntAsNumber : true,
});

async function query(sql, params = []) {
  let conn;
  try {
    conn = await pool.getConnection();
    return await conn.query(sql, params);
  } finally {
    if (conn) conn.release();
  }
}

module.exports = { query, pool };
