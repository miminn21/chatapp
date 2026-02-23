const { query } = require('./db');
const fs = require('fs');
const path = require('path');

async function initDatabase() {
  try {
    // Check if tables already exist (check for 'users' table)
    const tables = await query("SHOW TABLES LIKE 'users'");
    
    if (tables.length === 0) {
      console.log('📂 Database empty. Starting automatic initialization...');
      
      const schemaPath = path.join(__dirname, '../../schema_railway.sql');
      if (!fs.existsSync(schemaPath)) {
        console.error('❌ Schema file not found at:', schemaPath);
        return;
      }
      
      const schemaSql = fs.readFileSync(schemaPath, 'utf8');
      
      // Split by semicolon but ignore semicolons inside strings/quotes
      // A simple split is often enough for base schemas
      const queries = schemaSql
        .split(';')
        .map(q => q.trim())
        .filter(q => q.length > 0);
        
      for (let sql of queries) {
        await query(sql);
      }
      
      console.log('✅ Database schema initialized successfully!');
    } else {
      console.log('🗄️ Database already initialized (tables found).');
    }
  } catch (err) {
    console.error('❌ Automatic database initialization failed:', err.message);
  }
}

module.exports = initDatabase;
