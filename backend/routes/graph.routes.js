const express = require("express");
const router = express.Router();

const controller = require("../controllers/graph.controller");

router.post("/", controller.saveGraph);
router.get("/:floorplanId", controller.getGraph);

module.exports = router;
