const express = require("express");
const router = express.Router();

const controller = require("../controllers/image.controller");

router.post("/upload", controller.registerUpload);

module.exports = router;
