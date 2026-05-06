const https = require('https');
const fs = require('fs');
const path = require('path');

const API_BASE = 'https://bayan-rho.vercel.app/api/get-surah';
const OUTPUT_DIR = path.join(__dirname, 'output');
const TOTAL_SURAHS = 114;
const CONCURRENCY = 5; // parallel requests at a time
const DELAY_MS = 300;  // polite delay between batches

function fetchJSON(url) {
  return new Promise((resolve, reject) => {
    https.get(url, { headers: { 'User-Agent': 'Mozilla/5.0' } }, (res) => {
      let raw = '';
      res.on('data', (c) => (raw += c));
      res.on('end', () => {
        try { resolve(JSON.parse(raw)); }
        catch (e) { reject(new Error(`JSON parse failed for ${url}: ${e.message}`)); }
      });
    }).on('error', reject);
  });
}

function sleep(ms) {
  return new Promise((r) => setTimeout(r, ms));
}

async function scrapeSurah(n) {
  const data = await fetchJSON(`${API_BASE}/${n}`);
  if (!data.success) throw new Error(`API returned success=false for surah ${n}`);
  return data.data;
}

async function main() {
  if (!fs.existsSync(OUTPUT_DIR)) fs.mkdirSync(OUTPUT_DIR, { recursive: true });

  const surahs = Array.from({ length: TOTAL_SURAHS }, (_, i) => i + 1);
  const allData = {};
  let done = 0;

  for (let i = 0; i < surahs.length; i += CONCURRENCY) {
    const batch = surahs.slice(i, i + CONCURRENCY);
    await Promise.all(
      batch.map(async (n) => {
        try {
          const paragraphs = await scrapeSurah(n);
          allData[n] = paragraphs;

          // save per-surah file
          fs.writeFileSync(
            path.join(OUTPUT_DIR, `surah-${n}.json`),
            JSON.stringify(paragraphs, null, 2),
            'utf8'
          );
          done++;
          process.stdout.write(`\r  Progress: ${done}/${TOTAL_SURAHS} surahs`);
        } catch (err) {
          console.error(`\n  Error surah ${n}: ${err.message}`);
        }
      })
    );
    if (i + CONCURRENCY < surahs.length) await sleep(DELAY_MS);
  }

  // save combined file
  fs.writeFileSync(
    path.join(OUTPUT_DIR, 'all-surahs.json'),
    JSON.stringify(allData, null, 2),
    'utf8'
  );

  console.log(`\n\nDone! Files saved to: ${OUTPUT_DIR}`);
  console.log(`  - output/surah-{1..114}.json  (per surah)`);
  console.log(`  - output/all-surahs.json       (combined)`);

  // Print data shape summary
  const sample = allData[1]?.[1];
  if (sample) {
    console.log('\nData shape (one paragraph):');
    console.log('  Fields:', Object.keys(sample).join(', '));
    console.log('  arabic:', sample.arabic?.slice(0, 60), '...');
    console.log('  albtraur (Urdu translation):', sample.albtraur?.slice(0, 80), '...');
  }
}

main().catch(console.error);
