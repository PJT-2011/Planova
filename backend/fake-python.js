const express = require("express");
const app = express();

app.use(express.json());

app.post("/process", (req, res) => {
  console.log("Fake Python received:", req.body);

  res.json({
    status: "ok",
    nodes: [
      { id: "Entrance" },
      { id: "Hallway" },
      { id: "Room1" },
      { id: "Room2" }
    ],
    edges: [
      { from: "Entrance", to: "Hallway" },
      { from: "Hallway", to: "Room1" },
      { from: "Hallway", to: "Room2" }
    ]
  });
});

app.listen(7000, () => {
  console.log("Fake Python server running on port 7000");
});
