const {onDocumentCreated} = require("firebase-functions/v2/firestore");
const admin = require("firebase-admin");
const axios = require("axios");

admin.initializeApp();

exports.onFloorplanCreated = onDocumentCreated(
    "floorplans/{id}",
    async (event) => {
      const data = event.data.data();
      const floorplanId = event.params.id;

      console.log("New floorplan detected:", floorplanId);

      try {
        const response = await axios.post(
            "http://localhost:7000/process",
            {
              floorplanId,
              imageUrl: data.imageUrl,
            },
        );

        const {nodes, edges} = response.data;

        await admin.firestore()
            .collection("graphs")
            .doc(floorplanId)
            .set({
              nodes,
              edges,
              createdAt: new Date(),
            });

        await admin.firestore()
            .collection("floorplans")
            .doc(floorplanId)
            .update({
              processed: true,
            });

        console.log("Graph saved for:", floorplanId);
      } catch (err) {
        console.error("Processing failed:", err.message);
      }
    },
);
