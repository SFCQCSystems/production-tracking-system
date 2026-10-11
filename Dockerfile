FROM node:20-alpine

WORKDIR /app

# Copy all project files
COPY . .

# Environment variable for port
ENV PORT=3001
EXPOSE 3001

# Run the lightweight standalone MES server
CMD ["node", "server/server.js"]
