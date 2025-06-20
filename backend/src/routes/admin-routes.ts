import express, { NextFunction, Request, Response } from "express";
import { adminController } from "../controllers/admin-controller";
import { asyncHandler } from "../utils/asyncHandler";
import { jwtAuth, requireRole } from "../middleware/jwtAuth";
import { ROLES } from "../constants/roles";

const router = express.Router();

// All routes require admin role
router.use(jwtAuth,requireRole(ROLES.ADMIN));

router.get("/users", asyncHandler(adminController.getAllUsers));
router.get("/trainers", asyncHandler(adminController.getAllTrainers));
router.patch("/assign-trainer", asyncHandler(adminController.assignTrainer));
router.get("/payments", asyncHandler(adminController.getAllPayments));
router.post("/revoke-token", asyncHandler(adminController.revokeUserToken));

export default router;
