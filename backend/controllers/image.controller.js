const admin = require("../config/firebase");
const pythonService = require("../services/python.service");

/**
 * Register uploaded floorplan
 */
exports.registerUpload = async (req, res) => {
  try {
    const { imageUrl } = req.body;

    if (!imageUrl) {
      return res.status(400).json({ message: "imageUrl is required" });
    }

    // 1. Save floorplan
    const doc = await admin.firestore()
      .collection("floorplans")
      .add({
        imageUrl,
        processed: false,
        createdAt: new Date()
      });

    // 2. Call Python
    const result = await pythonService.processFloorplan({
      floorplanId: doc.id,
      imageUrl
    });

    // 3. Save graph if python returned data
    if (result && result.nodes && result.edges) {
      await admin.firestore()
        .collection("graphs")
        .add({
          floorplanId: doc.id,
          nodes: result.nodes,
          edges: result.edges,
          createdAt: new Date()
        });

      // 4. Mark floorplan as processed
      await admin.firestore()
        .collection("floorplans")
        .doc(doc.id)
        .update({ processed: true });
    }

    return res.status(201).json({
      message: "Floorplan registered",
      id: doc.id
    });

  } catch (err) {
    console.error(err);
    return res.status(500).json({ message: "Server error" });
  }
};


/**
 * Get processing status of a floorplan
 */
exports.getStatus = async (req, res) => {
  try {
    const { id } = req.params;

    const doc = await admin.firestore()
      .collection("floorplans")
      .doc(id)
      .get();

    if (!doc.exists) {
      return res.status(404).json({ message: "Floorplan not found" });
    }

    return res.json({
      processed: doc.data().processed
    });

  } catch (err) {
    console.error(err);
    return res.status(500).json({ message: "Server error" });
  }
};
