const mariadb = require('mariadb');

const pool = mariadb.createPool({
  host    : process.env.DB_HOST || 'localhost',
  user    : process.env.DB_USER || 'root',
  password: process.env.DB_PASS || '',
  database: process.env.DB_NAME || 'chatapp_db',
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
