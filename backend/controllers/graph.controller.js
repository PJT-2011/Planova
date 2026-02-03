const admin = require("../config/firebase");

/**
 * OPTIONAL: manual save (can keep)
 */
exports.saveGraph = async (req, res) => {
  try {
    const { floorplanId, nodes, edges } = req.body;

    if (!floorplanId || !nodes || !edges) {
      return res.status(400).json({
        message: "floorplanId, nodes, and edges are required"
      });
    }

    const doc = await admin.firestore()
      .collection("graphs")
      .add({
        floorplanId,
        nodes,
        edges,
        createdAt: new Date()
      });

    await admin.firestore()
      .collection("floorplans")
      .doc(floorplanId)
      .update({
        processed: true,
        graphId: doc.id
      });

    res.json({ message: "Graph saved successfully" });

  } catch (error) {
    console.error(error);
    res.status(500).json({ message: "Server error" });
  }
};


/**
 * MAIN METHOD (frontend will use this)
 */
exports.getGraphByFloorplan = async (req, res) => {
  try {
    const { floorplanId } = req.params;

    const snapshot = await admin.firestore()
      .collection("graphs")
      .where("floorplanId", "==", floorplanId)
      .limit(1)
      .get();

    if (snapshot.empty) {
      return res.status(404).json({ message: "Graph not found" });
    }

    const doc = snapshot.docs[0];

    res.json({
      id: doc.id,
      ...doc.data()
    });

  } catch (error) {
    console.error(error);
    res.status(500).json({ message: "Server error" });
  }
};
