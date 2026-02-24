require('dotenv').config();
const express = require('express');
const http    = require('http');
const cors    = require('cors');
const path    = require('path');
const { Server } = require('socket.io');

const authRoutes          = require('./src/routes/auth');
const userRoutes          = require('./src/routes/user');
const conversationRoutes  = require('./src/routes/conversations');
const groupRoutes         = require('./src/routes/groups');
const contactRoutes       = require('./src/routes/contact');
const messageRoutes       = require('./src/routes/messages');
const socketHandler       = require('./src/socket/socketHandler');

const app    = express();
const server = http.createServer(app);
const io     = new Server(server, { cors: { origin: '*', methods: ['GET', 'POST'] } });

// Middleware
app.use(cors());
app.use(express.json({ limit: '10mb' }));
app.use(express.urlencoded({ extended: true, limit: '10mb' }));

// Static
app.use('/uploads', express.static(path.join(__dirname, 'uploads')));

// REST Routes
app.use('/api/auth',           authRoutes);
app.use('/api/users',          userRoutes);
app.use('/api/conversations',  conversationRoutes);
app.use('/api/groups',         groupRoutes);
app.use('/api/contacts',       contactRoutes);
app.use('/api/messages',       messageRoutes);

// Routes
app.get('/', (req, res) => res.json({ status: 'ok', message: 'ChatApp Backend API' }));
app.get('/health', (req, res) => res.json({ status: 'healthy', timestamp: new Date() }));

// Socket.io
socketHandler(io);

// Start
const PORT = process.env.PORT || 3000;
const initDb = require('./src/config/initDb');

server.listen(PORT, async () => {
  console.log(`🚀 ChatApp backend running on http://localhost:${PORT}`);
  console.log('📡 Socket.io ready');
  
  // Auto-init database tables
  await initDb();
});
