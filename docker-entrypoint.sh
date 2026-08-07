#!/bin/sh

# Exit immediately if any command fails
set -e

echo "╔══════════════════════════════════════════════════════════════╗"
echo "║   Budget App Docker Entrypoint                               ║"
echo "╚══════════════════════════════════════════════════════════════╝"
echo ""
echo "⏳ Waiting for database connection via application network..."

# Use inline node runtime execution to block until TCP socket opens
node -e "
const net = require('net');
const host = process.env.DB_HOST || 'db';
const port = parseInt(process.env.DB_PORT || '5432', 10);
let attempts = 0;
const maxAttempts = 30;

function checkConnection() {
  attempts++;
  const socket = new net.Socket();

  socket.setTimeout(2000);

  socket.connect(port, host, () => {
    console.log('✅ Connected to database host successfully!');
    socket.destroy();
    process.exit(0);
  });

  socket.on('error', (err) => {
    socket.destroy();
    if (attempts >= maxAttempts) {
      console.error('❌ Error: Database connection timed out after ' + maxAttempts + ' attempts.');
      process.exit(1);
    }
    console.log('   Attempt ' + attempts + '/' + maxAttempts + ' - Database network interface not ready yet...');
    setTimeout(checkConnection, 2000);
  });

  socket.on('timeout', () => {
    socket.destroy();
    if (attempts >= maxAttempts) {
      console.error('❌ Error: Connection timed out.');
      process.exit(1);
    }
    console.log('   Attempt ' + attempts + '/' + maxAttempts + ' - Connection timed out, retrying...');
    setTimeout(checkConnection, 2000);
  });
}

checkConnection();
"

# Execute database migrations before launching production server if tracking state
if [ -f "./node_modules/.bin/prisma" ]; then
  echo "🔄 Running Prisma database migrations..."
  npx prisma migrate deploy || echo "⚠️ Migration step bypassed or already up to date."
fi

echo "🚀 Database dependencies satisfied. Starting application server..."
# Hand off process management back to Docker Engine CMD (e.g., node server.js or npm start)
exec "$@"
