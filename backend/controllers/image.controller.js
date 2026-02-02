const admin = require("../config/firebase");

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
  } catch (error) {
    console.error(error);
    return res.status(500).json({ message: "Server error" });
  }
};
