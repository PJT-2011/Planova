const admin = require("../config/firebase");

/**
 * Register uploaded floorplan
 */
exports.registerUpload = async (req, res) => {
  try {
    const { imageUrl } = req.body;

    if (!imageUrl) {
      return res.status(400).json({ message: "imageUrl is required" });
    }

    const doc = await admin.firestore()
      .collection("floorplans")
      .add({
        imageUrl,
        processed: false,
        createdAt: new Date()
      });

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
