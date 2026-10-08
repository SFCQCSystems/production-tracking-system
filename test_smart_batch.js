const fs = require('fs');
const path = require('path');
const orders = JSON.parse(fs.readFileSync(path.join(__dirname, 'sap_preloaded_orders.json'), 'utf8'));

function extractSmartBatch(colBatch, remark) {
  const b = (colBatch || '').trim();
  const rem = (remark || '').trim();
  
  // If colBatch is already a good complete batch (e.g. length > 4 and not just placeholder)
  const isPlaceholder = ['F', 'CC', 'cc', 'B', 'BB', 'b', 'f'].includes(b) || b.startsWith('F(');
  
  // Check if Remark has an explicit LOT : XXXXX
  const lotMatch = rem.match(/LOT\s*[:=]\s*([A-Za-z0-9_-]+)/i);
  if (lotMatch && lotMatch[1]) {
    return lotMatch[1].trim();
  }

  // Check if Remark has B24xxxxxx or B25xxxxxx or B26xxxxxx pattern
  const bPatternMatch = rem.match(/\b(B2[4-7]\d{6,8}[A-Za-z0-9_]*)\b/);
  if (bPatternMatch && bPatternMatch[1]) {
    return bPatternMatch[1].trim();
  }

  // If not placeholder, return original colBatch
  if (!isPlaceholder && b.length > 0) {
    return b;
  }

  return b; // Return original if nothing better
}

let enrichedCount = 0;
orders.forEach(o => {
  const smart = extractSmartBatch(o.batchNo, o.remark);
  if (smart && smart !== o.batchNo && (['', 'F', 'CC', 'cc', 'B'].includes(o.batchNo) || o.batchNo.length <= 3)) {
    enrichedCount++;
    if (enrichedCount <= 10) {
      console.log(`Order ${o.productionNo} (${o.orderType}):`);
      console.log(`  Col J original: "${o.batchNo}"`);
      console.log(`  Remark: "${o.remark}"`);
      console.log(`  -> Smart Batch Extracted: "${smart}"\n`);
    }
  }
});

console.log(`Total orders where full batch was successfully extracted from Remark: ${enrichedCount}`);
