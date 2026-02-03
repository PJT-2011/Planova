const express = require("express");
const router = express.Router();

const verifyToken = require("../middleware/auth.middleware");
const controller = require("../controllers/image.controller");

router.post("/upload", controller.registerUpload);
router.get("/:id/status", controller.getStatus);

module.exports = router;
