const { onObjectFinalized } = require('firebase-functions/v2/storage');
const { onRequest } = require('firebase-functions/v2/https');
const { defineSecret } = require('firebase-functions/params');
const admin = require('firebase-admin');
const { GoogleGenerativeAI } = require('@google/generative-ai');
const { processImage } = require('./gridProcessor');
const { constrainToOriginal, binarizeOriginal } = require('./wallMask');

admin.initializeApp();
const db = admin.firestore();
const storage = admin.storage();

const geminiApiKey = defineSecret('GEMINI_API_KEY');

// gemini-2.5-flash-image (your previous model) has an earliest shutdown
// date of Oct 2, 2026 — already past as of this deploy, so it may stop
// working at any time. gemini-3.1-flash-image-preview (what this constant
// used to say) is WRONG — that preview model was already shut down
// June 25, 2026. gemini-3.1-flash-image is the current, stable, non-preview
// replacement Google's deprecation table now points to. Recheck
// https://ai.google.dev/gemini-api/docs/deprecations before your next
// deploy, since this table changes often — don't assume this value is
// still current without checking.
// NOTE: confirm this model works with the installed @google/generative-ai
// version after deploying (check the function logs for the Gemini step).
const GEMINI_IMAGE_MODEL =
  process.env.GEMINI_IMAGE_MODEL || 'gemini-3.1-flash-image';

// How closely Gemini's picture must line up with the original before its
// furniture-removal is used (0..1). Every run logs the measured value, so
// tune this from real logs.
const MIN_GEMINI_AGREEMENT = Number(process.env.MIN_GEMINI_AGREEMENT || 0.7);

const GEMINI_CLEANING_PROMPT = `
You are editing a floorplan image for an indoor navigation app.

EDIT the given image — do NOT redraw it. Every wall that stays must remain
in EXACTLY the same position, length and shape as in the original.

Erase (paint white) only these things:
- All furniture (chairs, tables, sofas, beds, desks, appliances, fixtures)
- All text labels, room names, dimension lines and measurements
- Floor textures, tile patterns, hatching, colored fills
- Icons, symbols, watermarks, logos, legends
- Door swing arcs and door leaves (leave the wall opening as a white gap)
- Dashed or dotted lines, unless they mark a passage between two areas,
  in which case leave that passage as an open white gap

Keep (pure black #000000):
- Exterior walls and interior partition walls
- Staircase outer boundary and structural columns

Output requirements:
- Pure black on pure white, no gray
- Same size, proportions and orientation as the input. Do NOT crop, pad,
  mirror, rotate or flip.
- Do NOT add, move, extend or invent any wall or room.

Return ONLY the edited image, nothing else.
`.trim();

// ── Gemini call: returns a Buffer, or null if Gemini gave no image ───────────
async function cleanImageWithGemini(imageBuffer, contentType, apiKey) {
  if (!apiKey) throw new Error('Gemini API key not configured.');

  console.log(`🔵 Sending image to Gemini (${GEMINI_IMAGE_MODEL})...`);

  const genAI = new GoogleGenerativeAI(apiKey);
  const model = genAI.getGenerativeModel({
    model: GEMINI_IMAGE_MODEL,
    generationConfig: { responseModalities: ['TEXT', 'IMAGE'] },
  });

  const result = await model.generateContent([
    { inlineData: { mimeType: contentType, data: imageBuffer.toString('base64') } },
    GEMINI_CLEANING_PROMPT,
  ]);

  const response = await result.response;
  const parts = response.candidates?.[0]?.content?.parts;
  if (!parts || parts.length === 0) throw new Error('Gemini returned empty response');

  const imagePart = parts.find((p) => p.inlineData?.data);
  if (!imagePart) {
    console.warn('⚠️  Gemini returned no image');
    return null;
  }
  return Buffer.from(imagePart.inlineData.data, 'base64');
}

async function saveDebug(bucket, path, buffer) {
  try {
    await bucket.file(path).save(buffer, { contentType: 'image/png' });
    console.log(`🔍 DEBUG saved: ${path}`);
  } catch (e) {
    console.warn(`⚠️  Could not save debug image ${path}: ${e.message}`);
  }
}

/**
 * Builds the navigation grid for one floorplan image.
 *
 * Gemini only PROPOSES what to erase. The walls always come from the
 * original image (see wallMask.js). If Gemini fails, returns nothing, or
 * doesn't line up with the original, the grid is built from the original
 * image alone — so a Gemini outage or a bad redraw can no longer produce a
 * grid that disagrees with the picture users see.
 */
async function buildGridForImage({ originalBuffer, contentType, apiKey, bucket, debugPrefix }) {
  let inputForGrid = originalBuffer;
  let method = 'original_only';
  let agreement = null;
  let fallbackReason = null;

  try {
    const geminiBuffer = await cleanImageWithGemini(originalBuffer, contentType, apiKey);

    if (!geminiBuffer) {
      fallbackReason = 'gemini_no_image';
    } else {
      await saveDebug(bucket, `${debugPrefix}_gemini_cleaned.png`, geminiBuffer);

      const result = await constrainToOriginal(originalBuffer, geminiBuffer, {
        minAgreement: MIN_GEMINI_AGREEMENT,
      });
      agreement = result.agreement;
      console.log(
        `🔵 Gemini agreement=${result.agreement?.toFixed(3)} ` +
        `retention=${result.retention?.toFixed(3)} ok=${result.ok} ${result.reason || ''}`,
      );

      if (result.ok) {
        inputForGrid = result.buffer;
        method = 'gemini_constrained';
        await saveDebug(bucket, `${debugPrefix}_constrained.png`, result.buffer);
      } else {
        fallbackReason = result.reason;
      }
    }
  } catch (error) {
    // Gemini being down, out of quota or retired must not stop uploads.
    console.warn(`⚠️  Gemini step failed, using original image: ${error.message}`);
    fallbackReason = `gemini_error: ${error.message}`.slice(0, 200);
  }

  if (fallbackReason) {
    console.log(`⚠️  Gemini not used (${fallbackReason}) — binarizing original instead`);
    // IMPORTANT: never hand grid_processor a raw, unprocessed photo. It was
    // only ever tested against Gemini's clean black/white output, and a raw
    // photo (color tint, JPEG noise, gray shading) can push its classifier
    // into a weaker code path that misses thin walls, on top of furniture
    // and icons getting counted as walls outright. binarizeOriginal() forces
    // it down the same reliable code path Gemini's output used to, and
    // strips furniture-shaped blobs itself, with no AI involved.
    try {
      inputForGrid = await binarizeOriginal(originalBuffer);
      method = 'original_binarized';
      await saveDebug(bucket, `${debugPrefix}_binarized.png`, inputForGrid);
    } catch (e) {
      console.warn(`⚠️  binarizeOriginal failed, using raw original: ${e.message}`);
    }
  }

  const gridData = await processImage(inputForGrid, 15);
  return { gridData, method, agreement, fallbackReason };
}

// ── Main trigger ──────────────────────────────────────────────────────────────
exports.processFloorplan = onObjectFinalized(
  {
    timeoutSeconds: 300,
    memory: '1GiB',
    secrets: [geminiApiKey],
    region: 'asia-southeast1',
  },
  async (event) => {
    const filePath = event.data.name;
    const contentType = event.data.contentType;

    if (!filePath.startsWith('floorplans/') || !contentType.startsWith('image/')) {
      console.log(`⏭️  Skipping: ${filePath}`);
      return null;
    }

    const parts = filePath.split('/');
    if (parts.length !== 4) {
      console.log(`⏭️  Skipping unexpected path format: ${filePath}`);
      return null;
    }

    const userId = parts[1];
    const buildingId = parts[2];
    const floorId = parts[3].split('.')[0];

    console.log(`🔵 Processing: userId=${userId} buildingId=${buildingId} floorId=${floorId}`);

    const floorRef = db
      .collection('buildings')
      .doc(buildingId)
      .collection('floors')
      .doc(floorId);

    try {
      await floorRef.set({ status: 'processing' }, { merge: true });

      const bucket = storage.bucket(event.data.bucket);
      const [buffer] = await bucket.file(filePath).download();
      console.log(`✅ Downloaded image: ${buffer.length} bytes`);

      const { gridData, method, agreement, fallbackReason } = await buildGridForImage({
        originalBuffer: buffer,
        contentType,
        apiKey: geminiApiKey.value(),
        bucket,
        debugPrefix: `debug/${buildingId}/${floorId}`,
      });
      console.log(`✅ Grid processed: ${gridData.width}x${gridData.height} via ${method}`);

      // A new upload is a new image, so any earlier manual edits no longer
      // apply and review starts again.
      await floorRef.set({
        status: 'ready',
        processedData: gridData,
        processedAt: admin.firestore.FieldValue.serverTimestamp(),
        processingMethod: method,
        geminiAgreement: agreement,
        fallbackReason: fallbackReason || null,
        reviewStatus: 'needs_review',
        manuallyEdited: false,
        errorMessage: admin.firestore.FieldValue.delete(),
      }, { merge: true });

      console.log(`✅ Floorplan ${floorId} processing complete`);
      return null;
    } catch (error) {
      console.error(`❌ Error processing floorplan ${floorId}:`, error);
      await floorRef.set({
        status: 'failed',
        errorMessage: error.message || 'Unknown error',
      }, { merge: true }).catch(() => { });
      throw error;
    }
  },
);

// ── HTTP reprocess endpoint ───────────────────────────────────────────────────
// Body: { buildingId, floorId, imagePath, force? }
// Refuses to overwrite an admin's manual wall edits unless force is true.
exports.reprocessFloorplan = onRequest(
  {
    timeoutSeconds: 300,
    memory: '1GiB',
    secrets: [geminiApiKey],
    region: 'asia-southeast1',
  },
  async (req, res) => {
    if (req.method !== 'POST') {
      return res.status(405).json({ error: 'Method not allowed' });
    }

    const { buildingId, floorId, imagePath, force } = req.body;

    if (!buildingId || !floorId || !imagePath) {
      return res.status(400).json({
        error: 'Missing required fields: buildingId, floorId, imagePath',
      });
    }

    try {
      const floorRef = db
        .collection('buildings')
        .doc(buildingId)
        .collection('floors')
        .doc(floorId);

      const existing = await floorRef.get();
      if (existing.exists && existing.data().manuallyEdited === true && force !== true) {
        return res.status(409).json({
          error: 'This floor has manual wall edits. Send "force": true to overwrite them.',
        });
      }

      await floorRef.set({ status: 'processing' }, { merge: true });

      const bucket = storage.bucket();
      const [buffer] = await bucket.file(imagePath).download();
      const contentType = imagePath.toLowerCase().endsWith('.png') ? 'image/png' : 'image/jpeg';

      const { gridData, method, agreement, fallbackReason } = await buildGridForImage({
        originalBuffer: buffer,
        contentType,
        apiKey: geminiApiKey.value(),
        bucket,
        debugPrefix: `debug/reprocess/${floorId}`,
      });

      await floorRef.set({
        status: 'ready',
        processedData: gridData,
        processedAt: admin.firestore.FieldValue.serverTimestamp(),
        processingMethod: method,
        geminiAgreement: agreement,
        fallbackReason: fallbackReason || null,
        reviewStatus: 'needs_review',
        manuallyEdited: false,
        errorMessage: admin.firestore.FieldValue.delete(),
      }, { merge: true });

      return res.status(200).json({
        success: true,
        message: `Reprocessed ${floorId} successfully`,
        gridSize: `${gridData.width}x${gridData.height}`,
        method,
        geminiAgreement: agreement,
        fallbackReason: fallbackReason || null,
      });
    } catch (error) {
      console.error('❌ Reprocess error:', error);
      return res.status(500).json({ error: error.message });
    }
  },
);
