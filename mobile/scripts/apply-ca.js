const fs = require('fs');
const path = require('path');

const root = path.resolve(__dirname, '..');
const src = path.resolve(root, '..', 'certs', 'ca', 'ca.crt');
const destDir = path.resolve(root, 'android', 'app', 'src', 'main', 'res', 'raw');
const dest = path.join(destDir, 'my_ca.crt');

if (!fs.existsSync(src)) {
  console.error('Source CA not found at', src);
  process.exit(1);
}

if (!fs.existsSync(destDir)) {
  fs.mkdirSync(destDir, { recursive: true });
}

fs.copyFileSync(src, dest);
console.log('Copied CA to', dest);
