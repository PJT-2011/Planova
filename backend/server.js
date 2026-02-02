const express = require("express");
const cors = require("cors");
const imageRoutes = require("./routes/image.routes");


require("./config/firebase");
const verifyToken = require("./middleware/auth.middleware");

const app = express();
app.use(cors());
app.use(express.json());
app.use("/api/image", imageRoutes);

app.get("/", (req, res) => {
  res.send("Planova Backend Running");
});

app.get("/protected", verifyToken, (req, res) => {
  res.json({
    message: "You are authenticated",
    user: req.user.uid
  });
});

app.listen(5000, () => {
  console.log("Server running on port 5000");
});
