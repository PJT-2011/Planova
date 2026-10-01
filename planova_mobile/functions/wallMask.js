/**
 * wallMask.js
 *
 * Gemini's image model REDRAWS the floorplan, and can move, drop or invent
 * walls (it turned a real plan into a different layout in testing). So its
 * output is never trusted as the wall map. Instead it is used only as a
 * "furniture eraser hint":
 *
 *     kept walls = pixels that are dark in the ORIGINAL image
 *                  AND near a wall Gemini also drew
 *
 * Every kept pixel therefore comes from the original image, so Gemini can
 * remove things (furniture, text) but can never add or move a wall.
 *
 * It also measures how well Gemini's picture agrees with the original. If
 * Gemini drew walls where the original has none (a different layout), the
 * agreement score is low and the caller falls back to the original image.
 */

const sharp = require('sharp');

// ─── Otsu threshold on 8-bit gray ────────────────────────────────────────────
function otsu(gray) {
  const hist = new Array(256).fill(0);
  for (let i = 0; i < gray.length; i++) hist[gray[i]]++;
  const total = gray.length;
  let sum = 0;
  for (let i = 0; i < 256; i++) sum += i * hist[i];
  let sumB = 0, wB = 0, best = 0, thr = 128;
  for (let t = 0; t < 256; t++) {
    wB += hist[t];
    if (wB === 0) continue;
    const wF = total - wB;
    if (wF === 0) break;
    sumB += t * hist[t];
    const mB = sumB / wB;
    const mF = (sum - sumB) / wF;
    const v = wB * wF * (mB - mF) ** 2;
    if (v > best) { best = v; thr = t; }
  }
  return thr;
}

async function loadGray(buffer, width, height) {
  let img = sharp(buffer).flatten({ background: '#ffffff' }).greyscale();
  if (width && height) img = img.resize(width, height, { fit: 'fill' });
  const { data, info } = await img.raw().toBuffer({ resolveWithObject: true });
  return { data, width: info.width, height: info.height };
}

// Dark-pixel mask (1 = wall-ish ink).
function toMask(gray, threshold) {
  const m = new Uint8Array(gray.length);
  for (let i = 0; i < gray.length; i++) m[i] = gray[i] < threshold ? 1 : 0;
  return m;
}

// Separable square dilation: a pixel is set if any pixel within r is set.
function dilate(mask, w, h, r) {
  const tmp = new Uint8Array(w * h);
  const out = new Uint8Array(w * h);

  // horizontal pass using prefix sums
  for (let y = 0; y < h; y++) {
    const row = y * w;
    const pre = new Int32Array(w + 1);
    for (let x = 0; x < w; x++) pre[x + 1] = pre[x] + mask[row + x];
    for (let x = 0; x < w; x++) {
      const a = Math.max(0, x - r), b = Math.min(w - 1, x + r);
      tmp[row + x] = pre[b + 1] - pre[a] > 0 ? 1 : 0;
    }
  }
  // vertical pass
  for (let x = 0; x < w; x++) {
    const pre = new Int32Array(h + 1);
    for (let y = 0; y < h; y++) pre[y + 1] = pre[y] + tmp[y * w + x];
    for (let y = 0; y < h; y++) {
      const a = Math.max(0, y - r), b = Math.min(h - 1, y + r);
      out[y * w + x] = pre[b + 1] - pre[a] > 0 ? 1 : 0;
    }
  }
  return out;
}

function count(mask) {
  let n = 0;
  for (let i = 0; i < mask.length; i++) n += mask[i];
  return n;
}

// ─── Blob filter (no AI): drop furniture/icons, keep wall lines ─────────────
// A wall, even a long one, is THIN in at least one direction. A furniture
// icon or filled symbol is a compact blob: its bounding box is filled and
// roughly as wide as it is tall. So: 4-connect the dark mask into
// components, and drop any component whose bounding box is both densely
// filled AND thick in both directions. Long/thin components survive no
// matter how solid they are (a solid wall has fillRatio ~1 but is thin),
// and sparse/branchy components survive too (e.g. a chair's thin outline
// strokes, which real walls also look like). This only ever REMOVES ink —
// it can never turn a non-wall pixel into a wall, so it can't invent walls.
function stripBlobbyRegions(mask, w, h, opts = {}) {
  const maxThickness = opts.maxThickness ?? Math.max(4, Math.round(Math.min(w, h) * 0.012));
  const minFillToDrop = opts.minFillToDrop ?? 0.55;

  const label = new Int32Array(w * h).fill(-1);
  const out = new Uint8Array(mask);
  const stackX = new Int32Array(w * h);
  const stackY = new Int32Array(w * h);

  for (let sy = 0; sy < h; sy++) {
    for (let sx = 0; sx < w; sx++) {
      const start = sy * w + sx;
      if (!mask[start] || label[start] !== -1) continue;

      let sp = 0;
      stackX[sp] = sx; stackY[sp] = sy; sp++;
      label[start] = 1;

      let minX = sx, maxX = sx, minY = sy, maxY = sy, area = 0;
      const pixels = [];

      while (sp > 0) {
        sp--;
        const x = stackX[sp], y = stackY[sp];
        const idx = y * w + x;
        area++;
        pixels.push(idx);
        if (x < minX) minX = x;
        if (x > maxX) maxX = x;
        if (y < minY) minY = y;
        if (y > maxY) maxY = y;

        const nbrs = [[x - 1, y], [x + 1, y], [x, y - 1], [x, y + 1]];
        for (const [nx, ny] of nbrs) {
          if (nx < 0 || nx >= w || ny < 0 || ny >= h) continue;
          const nidx = ny * w + nx;
          if (mask[nidx] && label[nidx] === -1) {
            label[nidx] = 1;
            stackX[sp] = nx; stackY[sp] = ny; sp++;
          }
        }
      }

      const bw = maxX - minX + 1;
      const bh = maxY - minY + 1;
      const fillRatio = area / (bw * bh);
      const thick = bw > maxThickness && bh > maxThickness;

      if (thick && fillRatio > minFillToDrop) {
        for (const idx of pixels) out[idx] = 0;
      }
    }
  }

  return out;
}

/**
 * Clean black-on-white render of the ORIGINAL image alone, with furniture
 * and other blobby ink stripped out. No Gemini involved, so this always
 * works — it's what the fallback path uses instead of ever handing
 * grid_processor a raw, unprocessed photo. Otsu-thresholding also matters
 * on its own: it forces grid_processor's classifier down its best-tested
 * code path (avgSat≈0, grayRange≈255 → 'A_thin_walls', which is the only
 * branch that checks for thin spanning lines) instead of the weaker
 * colored/gray/compressed branches a raw photo can fall into, which is
 * why thin real walls could go undetected on a raw image even where no
 * furniture was in the way.
 */
async function binarizeOriginal(originalBuffer, opts = {}) {
  const orig = await loadGray(originalBuffer);
  const { data, width: w, height: h } = orig;
  const thr = Math.min(200, Math.max(60, otsu(data)));
  const mask = toMask(data, thr);
  const clean = stripBlobbyRegions(mask, w, h, opts);

  const out = Buffer.alloc(w * h, 255);
  for (let i = 0; i < clean.length; i++) if (clean[i]) out[i] = 0;
  return sharp(out, { raw: { width: w, height: h, channels: 1 } }).png().toBuffer();
}

/**
 * @returns {Promise<{ok:boolean, reason?:string, agreement:number|null,
 *                    retention:number|null, buffer?:Buffer}>}
 */
async function constrainToOriginal(originalBuffer, geminiBuffer, opts = {}) {
  const minAgreement = opts.minAgreement ?? 0.7;
  const minRetention = opts.minRetention ?? 0.10;
  const maxAspectDiff = opts.maxAspectDiff ?? 0.04;

  const orig = await loadGray(originalBuffer);
  const { width: w, height: h } = orig;

  // Reject if Gemini changed the aspect ratio (cropped/padded/re-framed):
  // squeezing it back to the original size would misalign every wall.
  const gm = await sharp(geminiBuffer).metadata();
  const aspectOrig = w / h;
  const aspectGem = gm.width / gm.height;
  if (Math.abs(aspectOrig - aspectGem) / aspectOrig > maxAspectDiff) {
    return { ok: false, reason: 'aspect_mismatch', agreement: null, retention: null };
  }

  const gem = await loadGray(geminiBuffer, w, h);

  const origThr = Math.min(200, Math.max(60, otsu(orig.data)));
  const origDark = toMask(orig.data, origThr);
  const gemDark = toMask(gem.data, 128);

  const gemCount = count(gemDark);
  const origCount = count(origDark);
  if (gemCount < 50 || origCount < 50) {
    return { ok: false, reason: 'empty_mask', agreement: null, retention: null };
  }

  // Tolerance for small misalignment / different line thickness.
  const r = Math.max(3, Math.round(Math.max(w, h) * 0.004));
  const origNear = dilate(origDark, w, h, r);
  const gemNear = dilate(gemDark, w, h, r);

  // Agreement: how much of what Gemini drew sits on real ink in the original.
  // A redrawn/different layout scores low here.
  let onOriginal = 0;
  for (let i = 0; i < gemDark.length; i++) {
    if (gemDark[i] && origNear[i]) onOriginal++;
  }
  const agreement = onOriginal / gemCount;

  // Kept walls: original ink that Gemini also considers wall, with
  // furniture-shaped blobs dropped the same way binarizeOriginal does —
  // Gemini is meant to erase furniture, but this is a second, non-AI
  // backstop for whatever it misses.
  let keep = new Uint8Array(w * h);
  for (let i = 0; i < keep.length; i++) {
    if (origDark[i] && gemNear[i]) keep[i] = 1;
  }
  keep = stripBlobbyRegions(keep, w, h);
  const kept = count(keep);
  const retention = kept / origCount;

  if (agreement < minAgreement) {
    return { ok: false, reason: 'low_agreement', agreement, retention };
  }
  if (retention < minRetention) {
    return { ok: false, reason: 'low_retention', agreement, retention };
  }

  // Black walls on white, same size as the original.
  const out = Buffer.alloc(w * h, 255);
  for (let i = 0; i < keep.length; i++) if (keep[i]) out[i] = 0;
  const png = await sharp(out, { raw: { width: w, height: h, channels: 1 } })
    .png()
    .toBuffer();

  return { ok: true, agreement, retention, buffer: png };
}

module.exports = { constrainToOriginal, binarizeOriginal };
