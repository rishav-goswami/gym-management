import express from "express";
import { trainerController } from "../controllers/trainer-controller";
import { asyncHandler } from "../utils/asyncHandler";
import { jwtAuth, requireRole } from "../middleware/jwtAuth";
import { ROLES } from "../constants/roles";

const router = express.Router();

// All routes require trainer role
router.use(jwtAuth, requireRole(ROLES.TRAINER));

router.get("/assigned-users", asyncHandler(trainerController.getAssignedUsers));
router.post("/assign-workout", asyncHandler(trainerController.assignWorkout));
router.post("/assign-diet", asyncHandler(trainerController.assignDiet));

export default router;
