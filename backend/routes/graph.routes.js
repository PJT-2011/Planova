const express = require("express");
const router = express.Router();

const verifyToken = require("../middleware/auth.middleware");
const controller = require("../controllers/graph.controller");

router.post("/", verifyToken, controller.saveGraph);
router.get("/:floorplanId", verifyToken, controller.getGraph);

module.exports = router;
