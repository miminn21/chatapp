FROM node:20

WORKDIR /app

# Copy package files and install dependencies
COPY backend/package*.json ./
RUN npm install

# Copy backend source code
COPY backend/ .

# Create uploads directory if it doesn't exist
RUN mkdir -p uploads

# Expose the application port
EXPOSE 3000

# Start the server
CMD ["node", "server.js"]
