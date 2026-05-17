const { onObjectFinalized } = require('firebase-functions/v2/storage');
const { onRequest } = require('firebase-functions/v2/https');
const { defineSecret } = require('firebase-functions/params');
const admin = require('firebase-admin');
const { GoogleGenerativeAI } = require('@google/generative-ai');
const { processImage } = require('./gridProcessor');

admin.initializeApp();
const db = admin.firestore();
const storage = admin.storage();

const geminiApiKey = defineSecret('GEMINI_API_KEY');

const GEMINI_CLEANING_PROMPT = `
You are a floorplan image processor for an indoor navigation app.

Your task: Convert this floorplan image into a clean black-on-white image 
that shows ONLY the structural walls and door openings.

KEEP (draw as solid black lines/areas):
- Exterior building walls (outer perimeter)
- Interior partition walls between rooms
- Door openings (leave as gaps in the wall lines)
- Staircase outlines (outer boundary only)
- Structural columns

REMOVE completely (leave as white/empty):
- All furniture (chairs, tables, sofas, beds, desks, appliances)
- All text labels and room names
- All dimension lines and measurements
- Floor textures, tile patterns, hatching
- Colored room fills
- Icons (fire extinguisher, emergency exit arrows, etc.)
- Decorative elements
- Watermarks and logos
- Legend boxes
- Grid lines

Output requirements:
- Pure black walls (#000000) on pure white background (#FFFFFF)
- Wall lines should be clean and continuous
- Door gaps should be clearly open (white/empty)
- No gray areas — only black and white
- Same proportions and scale as the original image

Return ONLY the cleaned image, nothing else.
`.trim();

// ── Main trigger ──────────────────────────────────────────────────────────────
// Storage path: floorplans/{userId}/{buildingId}/{floorId}.{ext}
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

    if (!filePath.startsWith('floorplans/') ||
      !contentType.startsWith('image/')) {
      console.log(`⏭️  Skipping: ${filePath}`);
      return null;
    }

    // Parse path: floorplans/{userId}/{buildingId}/{floorId}.{ext}
    const parts = filePath.split('/');
    if (parts.length !== 4) {
      console.log(`⏭️  Skipping unexpected path format: ${filePath}`);
      return null;
    }

    const userId = parts[1];
    const buildingId = parts[2];
    const floorId = parts[3].split('.')[0];

    console.log(`🔵 Processing: userId=${userId} buildingId=${buildingId} floorId=${floorId}`);

    // Write to buildings/{buildingId}/floors/{floorId}
    const floorRef = db
      .collection('buildings')
      .doc(buildingId)
      .collection('floors')
      .doc(floorId);

    try {
      await floorRef.update({ status: 'processing' });
      console.log('✅ Status set to processing');

      const bucket = storage.bucket(event.data.bucket);
      const [buffer] = await bucket.file(filePath).download();
      console.log(`✅ Downloaded image: ${buffer.length} bytes`);

      const cleanedBuffer = buffer; //replace with buffer to skip gemini again
      console.log(`✅ Using cleaned image: ${cleanedBuffer.length} bytes`);

      const gridData = await processImage(cleanedBuffer, 15);
      console.log(`✅ Grid processed: ${gridData.width}x${gridData.height}`);

      // Save processedData back to buildings/.../floors/...
      await floorRef.update({
        status: 'ready',
        processedData: gridData,
        processedAt: admin.firestore.FieldValue.serverTimestamp(),
      });

      console.log(`✅ Floorplan ${floorId} processing complete`);
      return null;

    } catch (error) {
      console.error(`❌ Error processing floorplan ${floorId}:`, error);

      await floorRef.update({
        status: 'failed',
        errorMessage: error.message || 'Unknown error',
      }).catch(() => { });

      throw error;
    }
  }
);

// ── Gemini image cleaning ─────────────────────────────────────────────────────
async function cleanImageWithGemini(imageBuffer, contentType, apiKey) {
  if (!apiKey) throw new Error('Gemini API key not configured.');

  console.log('🔵 Sending image to Gemini...');

  const genAI = new GoogleGenerativeAI(apiKey);
  const model = genAI.getGenerativeModel({ model: 'gemini-2.0-flash' });
  const base64Image = imageBuffer.toString('base64');

  const result = await model.generateContent([
    { inlineData: { mimeType: contentType, data: base64Image } },
    GEMINI_CLEANING_PROMPT,
  ]);

  const response = await result.response;
  const parts = response.candidates?.[0]?.content?.parts;

  if (!parts || parts.length === 0) throw new Error('Gemini returned empty response');

  const imagePart = parts.find(p => p.inlineData?.data);
  if (!imagePart) {
    console.warn('⚠️  Gemini returned no image, falling back to original');
    return imageBuffer;
  }

  console.log('✅ Gemini cleaning successful');
  return Buffer.from(imagePart.inlineData.data, 'base64');
}

// ── HTTP reprocess endpoint ───────────────────────────────────────────────────
// POST body: { buildingId, floorId, imagePath }
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

    const { buildingId, floorId, imagePath } = req.body;

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

      await floorRef.update({ status: 'processing' });

      const bucket = storage.bucket();
      const [buffer] = await bucket.file(imagePath).download();

      const contentType = imagePath.endsWith('.png') ? 'image/png' : 'image/jpeg';
      const apiKey = geminiApiKey.value();
      const cleanedBuffer = await cleanImageWithGemini(buffer, contentType, apiKey);
      const gridData = await processImage(cleanedBuffer, 15);

      await floorRef.update({
        status: 'ready',
        processedData: gridData,
        processedAt: admin.firestore.FieldValue.serverTimestamp(),
      });

      return res.status(200).json({
        success: true,
        message: `Reprocessed ${floorId} successfully`,
        gridSize: `${gridData.width}x${gridData.height}`,
      });

    } catch (error) {
      console.error('❌ Reprocess error:', error);
      return res.status(500).json({ error: error.message });
    }
  }
);