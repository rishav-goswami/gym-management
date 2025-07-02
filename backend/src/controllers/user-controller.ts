import { Request, Response } from "express";
import User from "../models/user";
import ApiResponse from "../utils/api_response";
import { z } from "zod";
import jwt from "jsonwebtoken";
import WorkoutRoutine from "../models/workout-routine";
import DietPlan from "../models/diet-plan";
import PaymentHistory from "../models/payment-history";
import PerformanceLogSchema from "../models/performance-log";

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
  verified: z.boolean().optional(),
  performance: z.array(z.any()).optional(),
});

function getUserIdFromRequest(req: Request): string | null {
  const user = req.user;
  return user ? user.id : null;
}

export const userController = {
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
