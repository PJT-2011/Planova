const admin = require("../config/firebase");

/**
 * OPTIONAL: manual save (can keep)
 */
exports.saveGraph = async (req, res, next) => {
  try {
    const { floorplanId, nodes, edges } = req.body;

    if (!floorplanId || !nodes || !edges) {
      return res.status(400).json({
        message: "floorplanId, nodes, and edges are required"
      });
    }

    if (typeof floorplanId !== "string") {
      return res.status(400).json({ message: "floorplanId must be a string" });
    }

    if (!Array.isArray(nodes) || !Array.isArray(edges)) {
      return res.status(400).json({
        message: "nodes and edges must be arrays"
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
    return next(error);
  }
};


/**
 * MAIN METHOD (frontend will use this)
 */
exports.getGraphByFloorplan = async (req, res, next) => {
  try {
    const { floorplanId } = req.params;

    if (!floorplanId || typeof floorplanId !== "string") {
      return res.status(400).json({ message: "Invalid floorplan id" });
    }

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
    return next(error);
  }
};
