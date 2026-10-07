const fs = require('fs');
const path = require('path');

const drives = ['C:\\', 'D:\\', 'E:\\', 'F:\\', 'I:\\'];
const found = [];

function search(dir, depth = 0) {
  if (depth > 4) return;
  try {
    const entries = fs.readdirSync(dir, { withFileTypes: true });
    for (const entry of entries) {
      const fullPath = path.join(dir, entry.name);
      const lower = entry.name.toLowerCase();

      if (entry.isFile()) {
        if (lower === 'adb.exe' || lower === 'sdkmanager.bat') {
          console.log('[FOUND FILE]', fullPath);
          found.push(fullPath);
        }
      } else if (entry.isDirectory()) {
        if (lower === 'android-sdk' || lower === 'androidsdk' || lower === 'sdk' || lower === 'android') {
          console.log('[POSSIBLE SDK DIR]', fullPath);
        }
        // Avoid slow system folders
        if (!['windows', 'programdata', '$recycle.bin', 'system volume information', 'node_modules', '.git'].includes(lower)) {
          search(fullPath, depth + 1);
        }
      }
    }
  } catch (e) {
    // skip permissions errors
  }
}

for (const drive of drives) {
  if (fs.existsSync(drive)) {
    console.log(`Scanning ${drive}...`);
    search(drive, 0);
  }
}

console.log('Search complete. Results:', found);
