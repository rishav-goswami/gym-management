import express from "express";

import { asyncHandler } from "../utils/asyncHandler";
import { userController } from "../controllers/user-controller";
import { jwtAuth, requireRole } from "../middleware/jwtAuth";
import { ROLES } from "../constants/roles";

const router = express.Router();
router.use(jwtAuth, requireRole(ROLES.MEMBER));

// Get current user profile
router.get("/me", asyncHandler(userController.getProfile));
router.get("/me/personal-info", asyncHandler(userController.getPersonalInfo));

// Update current user profile
router.put("/me", asyncHandler(userController.updateProfile));

// Fitness goals endpoints
router.get("/fitness-goals", asyncHandler(userController.getFitnessGoals));
router.put("/fitness-goals", asyncHandler(userController.updateFitnessGoals));

router.get(
  "/options/health-goals",
  asyncHandler(userController.getHealthGoalsOptions)
);
router.get(
  "/options/workout-frequencies",
  asyncHandler(userController.getWorkoutFrequencyOptions)
);
router.get("/options/workouts", asyncHandler(userController.searchWorkouts)); // Searchable workouts

// Get workout plan
router.get("/me/workout-plan", asyncHandler(userController.getWorkoutPlan));

// Route to get the list of all exercises from the library (with search)
// e.g., /api/users/exercises?search=squat&muscleGroup=Legs
router.get("/exercises", asyncHandler(userController.getExerciseLibrary));

// Route to get details for a single exercise
router.get("/exercises/:id", asyncHandler(userController.getExerciseDetails));

// Get diet plan
router.get("/diet", asyncHandler(userController.getDiet));
// Get payment history
router.get("/payments", asyncHandler(userController.getPayments));
// Log performance
router.post("/performance", asyncHandler(userController.logPerformance));

export default router;
