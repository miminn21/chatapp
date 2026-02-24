const { query } = require('./db');
const fs = require('fs');
const path = require('path');

async function initDatabase(retries = 5) {
  for (let i = 1; i <= retries; i++) {
    try {
      console.log(`📡 Checking database visibility (Attempt ${i}/${retries})...`);
      console.time(`⏱️  visibility-check-${i}`);
      const tables = await query("SHOW TABLES LIKE 'users'");
      console.timeEnd(`⏱️  visibility-check-${i}`);
      
      if (tables.length === 0) {
        console.log('📂 Database empty. Starting automatic initialization...');
        const schemaPath = path.join(__dirname, '../../schema_railway.sql');
        
        if (!fs.existsSync(schemaPath)) {
          console.error('❌ Schema file not found at:', schemaPath);
          return;
        }
        
        const schemaSql = fs.readFileSync(schemaPath, 'utf8');
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
      return; // Success, exit function
    } catch (err) {
      console.error(`⚠️ Attempt ${i} failed: ${err.message}`);
      if (i === retries) {
        console.error('❌ Final attempt failed. Database might be unreachable or credentials wrong.');
      } else {
        console.log('⏳ Waiting 3 seconds before next attempt...');
        await new Promise(res => setTimeout(res, 3000));
      }
    }
  }
}

module.exports = initDatabase;
