#!/bin/bash

echo "🚀 Setting up project..."

# Create src structure
mkdir -p src/{controllers,services,models,routes,middlewares,types,utils}

# Create files
touch src/app.ts src/server.ts

# Write basic app.ts
echo "import express from 'express';

const app = express();

app.use(express.json());

app.get('/', (req, res) => {
  res.send('API is running 🚀');
});

export default app;
" > src/app.ts

# Write basic server.ts
echo "import app from './app';

const PORT = process.env.PORT || 3000;

app.listen(PORT, () => {
  console.log(\`Server running on port \${PORT}\`);
});
" > src/server.ts

# Optional: initialize Node project
if [ ! -f package.json ]; then
  npm init -y
fi

# Install dependencies
npm install express

# Install dev dependencies
npm install -D typescript ts-node-dev @types/node @types/express

# Create tsconfig.json if not exists
if [ ! -f tsconfig.json ]; then
  npx tsc --init
fi

# Update package.json scripts
npx json -I -f package.json -e 'this.scripts={"dev":"ts-node-dev --respawn --transpile-only src/server.ts","build":"tsc","start":"node dist/server.js"}' 2>/dev/null

echo "✅ Setup complete!"