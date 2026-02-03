const axios = require("axios");
const admin = require("../config/firebase");

async function processFloorplan({ floorplanId, imageUrl }) {
  try {
    const response = await axios.post(
      "http://localhost:7000/process",
      { floorplanId, imageUrl }
    );

    const graphData = response.data;

    // Save graph
    const graphDoc = await admin.firestore()
      .collection("graphs")
      .add({
        ...graphData,
        floorplanId,
        createdAt: new Date()
      });

    // Update floorplan
    await admin.firestore()
      .collection("floorplans")
      .doc(floorplanId)
      .update({
        processed: true,
        graphId: graphDoc.id
      });

    console.log("Graph stored & floorplan updated");

    return graphDoc.id;

  } catch (err) {
    console.error("Python service error:", err.message);
    return null;
  }
}

module.exports = { processFloorplan };
