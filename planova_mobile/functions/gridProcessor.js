/**
 * gridProcessor.js — uses 'sharp' instead of Jimp
 * Logic is identical; only image-loading changed.
 */

const sharp = require('sharp');

// ─── Otsu threshold ───────────────────────────────────────────────────────────
function otsuThreshold(pixels) {
  const histogram = new Array(256).fill(0);
  for (const v of pixels) histogram[v]++;
  const total = pixels.length;
  let sum = 0;
  for (let i = 0; i < 256; i++) sum += i * histogram[i];

  let sumB = 0, wB = 0, maxVar = 0, threshold = 0;
  for (let t = 0; t < 256; t++) {
    wB += histogram[t];
    if (wB === 0) continue;
    const wF = total - wB;
    if (wF === 0) break;
    sumB += t * histogram[t];
    const mB = sumB / wB;
    const mF = (sum - sumB) / wF;
    const variance = wB * wF * (mB - mF) ** 2;
    if (variance > maxVar) { maxVar = variance; threshold = t; }
  }
  return threshold;
}

// ─── Classify image type ──────────────────────────────────────────────────────
function classifyImage(grayPixels, width, height, avgSat, grayRange) {
  const histogram = new Array(256).fill(0);
  for (const v of grayPixels) histogram[v]++;
  const modeVal = histogram.indexOf(Math.max(...histogram));

  if (grayRange < 200) return { type: 'E_compressed', modeVal };
  if (avgSat > 25) return { type: 'C_colored', modeVal };
  if (modeVal < 245) return { type: 'D_gray_floor', modeVal };

  const thresh = otsuThreshold(grayPixels);
  const binary = grayPixels.map(v => v < thresh ? 1 : 0);
  const medPx = measureMedianWallPx(binary, width, height);
  return medPx >= 8
    ? { type: 'B_thick_walls', modeVal }
    : { type: 'A_thin_walls', modeVal };
}

// ─── Measure median wall pixel thickness ──────────────────────────────────────
function measureMedianWallPx(binary, width, height) {
  const runs = [];
  const startY = Math.floor(height * 0.1);
  const endY = Math.floor(height * 0.9);

  for (let y = startY; y < endY; y += 10) {
    let inRun = false, runLen = 0;
    for (let x = 0; x < width; x++) {
      if (binary[y * width + x]) {
        inRun = true; runLen++;
      } else {
        if (inRun && runLen >= 2 && runLen <= 25) runs.push(runLen);
        inRun = false; runLen = 0;
      }
    }
  }
  if (runs.length === 0) return 3;
  runs.sort((a, b) => a - b);
  return runs[Math.floor(runs.length / 2)];
}

// ─── Spanning line check ──────────────────────────────────────────────────────
function hasSpanningLine(cellBinary, cellW, cellH, minSpanRatio = 0.40) {
  const minH = Math.max(3, Math.floor(cellW * minSpanRatio));
  const minV = Math.max(3, Math.floor(cellH * minSpanRatio));

  for (let r = 0; r < cellH; r++) {
    let run = 0;
    for (let c = 0; c < cellW; c++) {
      run = cellBinary[r * cellW + c] ? run + 1 : 0;
      if (run >= minH) return true;
    }
  }
  for (let c = 0; c < cellW; c++) {
    let run = 0;
    for (let r = 0; r < cellH; r++) {
      run = cellBinary[r * cellW + c] ? run + 1 : 0;
      if (run >= minV) return true;
    }
  }
  return false;
}

// ─── Build grid ───────────────────────────────────────────────────────────────
function buildGrid(binary, origW, origH, cellSize, useTier2, dilation) {
  const gridW = Math.floor(origW / cellSize);
  const gridH = Math.floor(origH / cellSize);
  let grid = Array.from({ length: gridH }, () => new Array(gridW).fill(0));

  for (let r = 0; r < gridH; r++) {
    for (let c = 0; c < gridW; c++) {
      const x0 = c * cellSize, y0 = r * cellSize;
      const x1 = Math.min(x0 + cellSize, origW);
      const y1 = Math.min(y0 + cellSize, origH);
      const cW = x1 - x0, cH = y1 - y0;

      const cell = [];
      for (let y = y0; y < y1; y++)
        for (let x = x0; x < x1; x++)
          cell.push(binary[y * origW + x]);

      const ratio = cell.reduce((s, v) => s + v, 0) / cell.length;

      if (ratio > 0.20) {
        grid[r][c] = 1;
      } else if (ratio > 0.04 && useTier2) {
        if (hasSpanningLine(cell, cW, cH, 0.40)) grid[r][c] = 1;
      }
    }
  }

  if (dilation > 0) {
    const newGrid = grid.map(row => [...row]);
    for (let r = 1; r < gridH - 1; r++) {
      for (let c = 1; c < gridW - 1; c++) {
        if (grid[r][c] === 1) {
          newGrid[r - 1][c] = 1; newGrid[r + 1][c] = 1;
          newGrid[r][c - 1] = 1; newGrid[r][c + 1] = 1;
        }
      }
    }
    grid = newGrid;
  }

  const cleaned = grid.map(row => [...row]);
  for (let r = 1; r < gridH - 1; r++) {
    for (let c = 1; c < gridW - 1; c++) {
      if (grid[r][c] === 1) {
        const n = grid[r - 1][c] + grid[r + 1][c] + grid[r][c - 1] + grid[r][c + 1];
        if (n <= 1) cleaned[r][c] = 0;
      }
    }
  }

  for (let t = 0; t < 2; t++) {
    for (let c = 0; c < gridW; c++) {
      cleaned[t][c] = 1;
      cleaned[gridH - 1 - t][c] = 1;
    }
    for (let r = 0; r < gridH; r++) {
      cleaned[r][t] = 1;
      cleaned[r][gridW - 1 - t] = 1;
    }
  }

  return { grid: cleaned, gridW, gridH };
}

// ─── Main export ──────────────────────────────────────────────────────────────
async function processImage(imageBuffer, cellSize = 15) {
  console.log('🔵 [GRID] Starting grid processing...');

  // ── Load image with sharp (replaces Jimp) ────────────────────────────────
  const { data, info } = await sharp(imageBuffer)
    .ensureAlpha()          // adds alpha channel if missing
    .raw()                  // raw RGBA pixel buffer
    .toBuffer({ resolveWithObject: true });

  const origW = info.width;
  const origH = info.height;
  const channels = info.channels; // 4 (RGBA)
  console.log(`✅ [GRID] Image: ${origW}x${origH} channels=${channels}`);

  // Extract grayscale + saturation from RGBA buffer
  const grayPixels = [];
  const rgbPixels = { r: [], g: [], b: [] };

  for (let i = 0; i < data.length; i += channels) {
    const r = data[i];
    const g = data[i + 1];
    const b = data[i + 2];
    // alpha = data[i + 3] — ignored
    const gray = Math.round(0.299 * r + 0.587 * g + 0.114 * b);
    grayPixels.push(gray);
    rgbPixels.r.push(r);
    rgbPixels.g.push(g);
    rgbPixels.b.push(b);
  }

  let satSum = 0;
  for (let i = 0; i < grayPixels.length; i++) {
    satSum += Math.max(rgbPixels.r[i], rgbPixels.g[i], rgbPixels.b[i])
      - Math.min(rgbPixels.r[i], rgbPixels.g[i], rgbPixels.b[i]);
  }
  const avgSat = satSum / grayPixels.length;
  let grayMin = 255, grayMax = 0;
  for (const v of grayPixels) {
    if (v < grayMin) grayMin = v;
    if (v > grayMax) grayMax = v;
  }
  const grayRange = grayMax - grayMin;

  console.log(`🔵 [GRID] avgSat=${avgSat.toFixed(1)}, range=${grayRange}`);

  let { type: imgType, modeVal } = classifyImage(grayPixels, origW, origH, avgSat, grayRange);
  console.log(`✅ [GRID] Image type: ${imgType}, mode=${modeVal}`);

  let working = [...grayPixels];

  if (imgType === 'E_compressed') {
    working = grayPixels.map(v =>
      Math.min(255, Math.max(0, Math.round((v - grayMin) / Math.max(grayMax - grayMin, 1) * 255)))
    );
    const mean = working.reduce((s, v) => s + v, 0) / working.length;
    working = working.map(v => Math.min(255, Math.max(0, Math.round(mean + (v - mean) * 2.0))));
    const newHist = new Array(256).fill(0);
    for (const v of working) newHist[v]++;
    modeVal = newHist.indexOf(Math.max(...newHist));
    imgType = modeVal < 245 ? 'D_gray_floor' : 'A_thin_walls';
  } else if (imgType === 'C_colored') {
    working = [];
    for (let i = 0; i < grayPixels.length; i++) {
      working.push(Math.min(rgbPixels.r[i], rgbPixels.g[i], rgbPixels.b[i]));
    }
  }

  if (modeVal <= 128) {
    working = working.map(v => 255 - v);
    const newHist = new Array(256).fill(0);
    for (const v of working) newHist[v]++;
    modeVal = newHist.indexOf(Math.max(...newHist));
    console.log(`✅ [GRID] Inverted, new mode=${modeVal}`);
  }

  let thresh, useTier2, dilation;

  if (imgType === 'A_thin_walls') {
    thresh = otsuThreshold(working); useTier2 = true; dilation = 0;
  } else if (imgType === 'B_thick_walls') {
    thresh = otsuThreshold(working); useTier2 = false; dilation = 0;
  } else if (imgType === 'C_colored') {
    thresh = otsuThreshold(working); useTier2 = false;
    const binary = working.map(v => v < thresh ? 1 : 0);
    const medPx = measureMedianWallPx(binary, origW, origH);
    const wFrac = medPx / cellSize;
    dilation = (wFrac < 0.20 || wFrac > 0.40) ? 0 : 1;
  } else {
    thresh = Math.max(30, modeVal - 80);
    const binary = working.map(v => v < thresh ? 1 : 0);
    const medPx = measureMedianWallPx(binary, origW, origH);
    const wFrac = medPx / cellSize;
    useTier2 = wFrac < 0.20;
    dilation = (wFrac < 0.20 || wFrac > 0.40) ? 0 : 1;
  }

  console.log(`✅ [GRID] thresh=${thresh}, tier2=${useTier2}, dilation=${dilation}`);

  const binary = working.map(v => v < thresh ? 1 : 0);
  const { grid, gridW, gridH } = buildGrid(binary, origW, origH, cellSize, useTier2, dilation);

  const flatGrid = grid.flat();
  const wallCells = flatGrid.reduce((s, v) => s + v, 0);
  const totalCells = gridW * gridH;
  const finalWallPct = (wallCells / totalCells * 100).toFixed(1);

  console.log(`✅ [GRID] Final: ${gridW}x${gridH}, walls=${wallCells} (${finalWallPct}%)`);

  return {
    grid: flatGrid,
    width: gridW,
    height: gridH,
    cellSize: cellSize,
    metadata: {
      imageWidth: origW,
      imageHeight: origH,
      wallCells: wallCells,
      walkableCells: totalCells - wallCells,
      processingTime: 0,
      imageType: imgType,
    },
  };
}

module.exports = { processImage };