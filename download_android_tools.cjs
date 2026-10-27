const fs = require('fs');
const path = require('path');
const https = require('https');
const { execSync } = require('child_process');

const CACHE_DIR = 'I:\\setup_cache';
const JAVA_DIR = 'I:\\Java\\jdk-17';
const ANDROID_SDK_DIR = 'I:\\SDKfile';

if (!fs.existsSync(CACHE_DIR)) fs.mkdirSync(CACHE_DIR, { recursive: true });
if (!fs.existsSync(JAVA_DIR)) fs.mkdirSync(JAVA_DIR, { recursive: true });
if (!fs.existsSync(ANDROID_SDK_DIR)) fs.mkdirSync(ANDROID_SDK_DIR, { recursive: true });

function downloadFile(url, destPath) {
  return new Promise((resolve, reject) => {
    if (fs.existsSync(destPath) && fs.statSync(destPath).size > 10 * 1024 * 1024) {
      console.log(`[SKIP] Already downloaded: ${destPath}`);
      return resolve();
    }
    console.log(`[DOWNLOAD] Starting: ${url} -> ${destPath}`);
    const file = fs.createWriteStream(destPath);
    
    function makeRequest(currentUrl) {
      https.get(currentUrl, (response) => {
        if (response.statusCode >= 300 && response.statusCode < 400 && response.headers.location) {
          console.log(`[REDIRECT] Following redirect to: ${response.headers.location}`);
          return makeRequest(response.headers.location);
        }
        if (response.statusCode !== 200) {
          file.close();
          try { fs.unlinkSync(destPath); } catch (e) {}
          return reject(new Error(`HTTP ${response.statusCode} while downloading ${currentUrl}`));
        }
        let total = parseInt(response.headers['content-length'] || '0', 10);
        let downloaded = 0;
        let lastReport = Date.now();

        response.on('data', (chunk) => {
          downloaded += chunk.length;
          file.write(chunk);
          if (Date.now() - lastReport > 3000) {
            const mb = (downloaded / (1024 * 1024)).toFixed(1);
            const totalMb = (total / (1024 * 1024)).toFixed(1);
            console.log(`[PROGRESS] ${mb} MB / ${totalMb} MB (${Math.round((downloaded / total) * 100)}%)`);
            lastReport = Date.now();
          }
        });

        response.on('end', () => {
          file.end(() => {
            console.log(`[DONE] Finished download: ${destPath}`);
            resolve();
          });
        });
      }).on('error', (err) => {
        file.close();
        try { fs.unlinkSync(destPath); } catch (e) {}
        reject(err);
      });
    }

    makeRequest(url);
  });
}

async function run() {
  try {
    // 1. Download OpenJDK 17
    const jdkZip = path.join(CACHE_DIR, 'jdk17.zip');
    await downloadFile('https://api.adoptium.net/v3/binary/latest/17/ga/windows/x64/jdk/hotspot/normal/eclipse?project=jdk', jdkZip);

    // 2. Extract OpenJDK 17
    console.log('[EXTRACT] Extracting OpenJDK 17 to ' + JAVA_DIR);
    execSync(`powershell -Command "Expand-Archive -Path '${jdkZip}' -DestinationPath 'I:\\Java\\temp_jdk' -Force"`, { stdio: 'inherit' });
    const tempJdkDirs = fs.readdirSync('I:\\Java\\temp_jdk');
    if (tempJdkDirs.length === 1 && fs.statSync(path.join('I:\\Java\\temp_jdk', tempJdkDirs[0])).isDirectory()) {
      const innerDir = path.join('I:\\Java\\temp_jdk', tempJdkDirs[0]);
      execSync(`powershell -Command "Move-Item -Path '${innerDir}\\*' -Destination '${JAVA_DIR}' -Force"`, { stdio: 'inherit' });
      fs.rmdirSync('I:\\Java\\temp_jdk', { recursive: true });
    }
    console.log('[SUCCESS] JDK 17 installed to ' + JAVA_DIR);

    // 3. Download Android Command Line Tools
    const cmdlineZip = path.join(CACHE_DIR, 'cmdline-tools.zip');
    await downloadFile('https://dl.google.com/android/repository/commandlinetools-win-11076708_latest.zip', cmdlineZip);

    // 4. Extract Command Line Tools
    const cmdlineTarget = path.join(ANDROID_SDK_DIR, 'cmdline-tools', 'latest');
    fs.mkdirSync(cmdlineTarget, { recursive: true });
    console.log('[EXTRACT] Extracting Command Line Tools to ' + cmdlineTarget);
    execSync(`powershell -Command "Expand-Archive -Path '${cmdlineZip}' -DestinationPath 'I:\\Android\\temp_cmd' -Force"`, { stdio: 'inherit' });
    const innerCmd = 'I:\\Android\\temp_cmd\\cmdline-tools';
    execSync(`powershell -Command "Move-Item -Path '${innerCmd}\\*' -Destination '${cmdlineTarget}' -Force"`, { stdio: 'inherit' });
    fs.rmdirSync('I:\\Android\\temp_cmd', { recursive: true });
    console.log('[SUCCESS] Android cmdline-tools installed to ' + cmdlineTarget);

    // 5. Configure Flutter SDK
    console.log('[CONFIG] Configuring Flutter with Android SDK & JDK 17...');
    execSync(`I:\\flutter\\bin\\flutter.bat config --android-sdk "${ANDROID_SDK_DIR}"`, { stdio: 'inherit' });
    execSync(`I:\\flutter\\bin\\flutter.bat config --jdk-dir "${JAVA_DIR}"`, { stdio: 'inherit' });

    console.log('[COMPLETE] Android toolchain base is ready on Drive I:!');
  } catch (err) {
    console.error('[ERROR]', err);
    process.exit(1);
  }
}

run();
