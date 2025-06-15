import express from "express";

import { asyncHandler } from "../utils/asyncHandler";
import { userController } from "../controllers/user-controller";

const router = express.Router();

// Get current user profile
router.get("/me", asyncHandler(userController.getProfile));

// Update current user profile
router.put("/me", asyncHandler(userController.updateProfile));

export default router;
