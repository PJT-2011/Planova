const express = require("express");
const router = express.Router();

const controller = require("../controllers/graph.controller");

// GET graph using floorplanId
router.get("/:floorplanId", controller.getGraphByFloorplan);

module.exports = router;
