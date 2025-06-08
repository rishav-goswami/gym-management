import express, { Request, Response, Router } from "express";
import { authController } from "../controllers/auth-controller";
import { asyncHandler } from "../utils/asyncHandler";

const router: Router = express.Router();

// Register route
router.post("/register", asyncHandler(authController.register));

// Login route
router.post("/login", asyncHandler(authController.login));

// Logout route
router.post("/logout", asyncHandler(authController.logout));

export default router;
