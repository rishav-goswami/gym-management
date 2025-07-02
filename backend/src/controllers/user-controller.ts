import { Request, Response } from "express";
import User from "../models/user";
import ApiResponse from "../utils/api_response";
import { z } from "zod";
import jwt from "jsonwebtoken";
import WorkoutRoutine from "../models/workout-routine";
import Workout from "../models/workout";
import DietPlan from "../models/diet-plan";
import PaymentHistory from "../models/payment-history";
import PerformanceLogSchema from "../models/performance-log";

declare global {
  namespace Express {
    interface Request {
      user?: Object | any;
    }
  }
}

const updateProfileSchema = z.object({
  name: z.string().min(2).optional(),
  email: z.string().email().optional(),
  phone: z.number().min(1000000000).max(9999999999).optional(),
  avatarUrl: z.string().optional(),
  bio: z.string().max(500).optional(),
  dob: z.string().optional(), // ISO string
  gender: z.enum(["male", "female", "other"]).optional(),
  height: z.number().min(0).max(300).optional(),
  weight: z.number().min(0).max(500).optional(),
  healthGoals: z.string().optional(),
  workoutFrequency: z.string().optional(),
  preferredWorkouts: z
    .array(z.string().or(z.object({ _id: z.string() })))
    .optional(),
  preferredWorkoutTime: z.string().optional(),
  verified: z.boolean().optional(),
  performance: z.array(z.any()).optional(),
});

const fitnessGoalsSchema = z.object({
  healthGoals: z.string().optional(),
  workoutFrequency: z.string().optional(),
  preferredWorkouts: z.array(z.string()).optional(),
  preferredWorkoutTime: z.string().optional(),
});

// Utility to get userId from request
function getUserIdFromRequest(req: Request): string | null {
  const user = req.user;
  return user ? user.id : null;
}

export const userController = {
  // Get fitness goals for the current user, with preferredWorkouts populated
  getFitnessGoals: async (req: Request, res: Response) => {
    const userId = getUserIdFromRequest(req);
    // const xy = Workout.find({});
    if (!userId) return ApiResponse.error(res, "Unauthorized", 401);
    const user = await User.findById(userId)
      .select(
        "healthGoals workoutFrequency preferredWorkouts preferredWorkoutTime"
      )
      .populate({ path: "preferredWorkouts" });
    if (!user) return ApiResponse.error(res, "User not found", 404);
    return ApiResponse.success(res, user, "Fitness goals fetched");
  },

  // Update fitness goals for the current user
  updateFitnessGoals: async (req: Request, res: Response) => {
    const userId = getUserIdFromRequest(req);
    if (!userId) return ApiResponse.error(res, "Unauthorized", 401);
    const parsed = fitnessGoalsSchema.safeParse(req.body);
    if (!parsed.success) {
      return ApiResponse.validationError(
        res,
        parsed.error,
        "Validation failed"
      );
    }
    const update = parsed.data;
    // If preferredWorkouts is present, ensure it is an array of ObjectIds (strings)
    if (update.preferredWorkouts) {
      update.preferredWorkouts = update.preferredWorkouts.map((id: any) =>
        typeof id === "string" ? id : id._id
      );
    }
    const user = await User.findByIdAndUpdate(userId, update, {
      new: true,
      runValidators: true,
    })
      .select(
        "healthGoals workoutFrequency preferredWorkouts preferredWorkoutTime"
      )
      .populate({ path: "preferredWorkouts" });
    if (!user) return ApiResponse.error(res, "User not found", 404);
    return ApiResponse.success(res, user, "Fitness goals updated");
  },

  getProfile: async (req: Request, res: Response) => {
    const userId = getUserIdFromRequest(req);
    if (!userId) return ApiResponse.error(res, "Unauthorized", 401);
    const user = await User.findById(userId)
      .select("-password")
      .populate("subscription performance trainerId");
    if (!user) return ApiResponse.error(res, "User not found", 404);
    return ApiResponse.success(res, user, "Profile fetched");
  },

  updateProfile: async (req: Request, res: Response) => {
    const userId = getUserIdFromRequest(req);
    if (!userId) return ApiResponse.error(res, "Unauthorized", 401);
    const parsed = updateProfileSchema.safeParse(req.body);
    if (!parsed.success) {
      return ApiResponse.validationError(
        res,
        parsed.error,
        "Validation failed"
      );
    }
    const update = parsed.data;
    const user = await User.findByIdAndUpdate(userId, update, {
      new: true,
      runValidators: true,
    }).select("-password");
    if (!user) return ApiResponse.error(res, "User not found", 404);
    return ApiResponse.success(res, user, "Profile updated");
  },

  getWorkout: async (req: Request, res: Response) => {
    const userId = getUserIdFromRequest(req);
    if (!userId) return ApiResponse.error(res, "Unauthorized", 401);
    const routine = await WorkoutRoutine.findOne({ userId });
    return ApiResponse.success(res, { routine });
  },

  getDiet: async (req: Request, res: Response) => {
    const userId = getUserIdFromRequest(req);
    if (!userId) return ApiResponse.error(res, "Unauthorized", 401);
    const diet = await DietPlan.findOne({ userId });
    return ApiResponse.success(res, { diet });
  },

  getPayments: async (req: Request, res: Response) => {
    const userId = getUserIdFromRequest(req);
    if (!userId) return ApiResponse.error(res, "Unauthorized", 401);
    const payments = await PaymentHistory.find({ userId });
    return ApiResponse.success(res, payments);
  },

  logPerformance: async (req: Request, res: Response) => {
    const userId = getUserIdFromRequest(req);
    if (!userId) return ApiResponse.error(res, "Unauthorized", 401);
    const { date, weight, caloriesBurned, notes } = req.body;
    const log = await PerformanceLogSchema.create({
      date,
      weight,
      caloriesBurned,
      notes,
    });
    await User.findByIdAndUpdate(userId, { $push: { performance: log._id } });
    return ApiResponse.success(res, log);
  },
};
