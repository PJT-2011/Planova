const admin = require("../config/firebase");

exports.saveGraph = async (req, res) => {
  try {
    const { floorplanId, nodes, edges } = req.body;

    if (!floorplanId || !nodes || !edges) {
      return res.status(400).json({
        message: "floorplanId, nodes, and edges are required"
      });
    }

    await admin.firestore()
      .collection("graphs")
      .doc(floorplanId)
      .set({
        nodes,
        edges,
        createdAt: new Date()
      });

    await admin.firestore()
      .collection("floorplans")
      .doc(floorplanId)
      .update({
        processed: true
      });

    res.json({ message: "Graph saved successfully" });

  } catch (error) {
    console.error(error);
    res.status(500).json({ message: "Server error" });
  }
};

exports.getGraph = async (req, res) => {
  try {
    const { floorplanId } = req.params;

    const doc = await admin.firestore()
      .collection("graphs")
      .doc(floorplanId)
      .get();

    if (!doc.exists) {
      return res.status(404).json({ message: "Graph not found" });
    }

    res.json(doc.data());

  } catch (error) {
    console.error(error);
    res.status(500).json({ message: "Server error" });
  }
};
