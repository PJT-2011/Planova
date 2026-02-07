const express = require("express");
const cors = require("cors");
const crypto = require("crypto");
const imageRoutes = require("./routes/image.routes");
const graphRoutes = require("./routes/graph.routes");

require("./config/firebase");
const verifyToken = require("./middleware/auth.middleware");

const app = express();
app.use(cors());
app.use(express.json());

// Simple request logging with correlation id for tracing errors
app.use((req, res, next) => {
  const requestId = crypto.randomUUID();
  res.locals.requestId = requestId;
  res.set("X-Request-Id", requestId);

  const startTime = Date.now();
  res.on("finish", () => {
    const durationMs = Date.now() - startTime;
    console.log(
      `[${requestId}] ${req.method} ${req.originalUrl} ${res.statusCode} ${durationMs}ms`
    );
  });

  next();
});
app.use("/api/image", imageRoutes);
app.use("/api/graph", graphRoutes);


app.get("/", (req, res) => {
  res.send("Planova Backend Running");
});

app.get("/protected", verifyToken, (req, res) => {
  res.json({
    message: "You are authenticated",
    user: req.user.uid
  });
});

// Central error handler
app.use((err, req, res, next) => {
  const requestId = res.locals.requestId || "unknown";
  console.error(`[${requestId}]`, err);

  res.status(err.status || 500).json({
    message: err.message || "Server error",
    requestId
  });
});

app.listen(5000, () => {
  console.log("Server running on port 5000");
});
