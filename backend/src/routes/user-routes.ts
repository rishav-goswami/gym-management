import express from "express";

import { asyncHandler } from "../utils/asyncHandler";
import { userController } from "../controllers/user-controller";

const router = express.Router();

// Get current user profile
router.get("/me", asyncHandler(userController.getProfile));

// Update current user profile
router.put("/me", asyncHandler(userController.updateProfile));

// Get workout routine
router.get('/workout', asyncHandler(userController.getWorkout));
// Get diet plan
router.get('/diet', asyncHandler(userController.getDiet));
// Get payment history
router.get('/payments', asyncHandler(userController.getPayments));
// Log performance
router.post('/performance', asyncHandler(userController.logPerformance));

export default router;
