import { Request, Response } from "express";
import User from "../models/user";
import ApiResponse from "../utils/api_response"; // Assuming this utility exists
import { z } from "zod";
import jwt from "jsonwebtoken"; // Ensure this is for token decoding if used, otherwise remove if only `req.user` is relied on
import WorkoutRoutine from "../models/workout-routine"; // Unused in this snippet, keep if needed elsewhere
import Workout from "../models/workout"; // Existing Workout model
import DietPlan from "../models/diet-plan"; // Unused
import PaymentHistory from "../models/payment-history"; // Unused
import PerformanceLogSchema from "../models/performance-log"; // Unused
import HealthGoal from "../models/health-goals"; // NEW: HealthGoal Model
import WorkoutFrequency from "../models/workout-frequency"; // NEW: WorkoutFrequency Model

declare global {
  namespace Express {
    interface Request {
      user?: Object | any; // Ensure this correctly types req.user from your auth middleware
    }
  }
}

// Ensure these schemas align with your User model update requirements
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
  healthGoals: z.string().optional(), // Now refers to ID from HealthGoal model
  workoutFrequency: z.string().optional(), // Now refers to ID from WorkoutFrequency model
  preferredWorkouts: z
    .array(z.string().or(z.object({ _id: z.string() })))
    .optional(),
  preferredWorkoutTime: z.string().optional(),
  verified: z.boolean().optional(),
  performance: z.array(z.any()).optional(),
});

const fitnessGoalsSchema = z.object({
  healthGoals: z.string().optional(), // Expecting HealthGoal _id
  workoutFrequency: z.string().optional(), // Expecting WorkoutFrequency _id
  preferredWorkouts: z.array(z.string()).optional(), // Expecting Workout _id
  preferredWorkoutTime: z.string().optional(),
});

// Utility to get userId from request (Assuming this is handled by auth middleware populating req.user)
function getUserIdFromRequest(req: Request): string | null {
  const user = req.user;
  return user ? user.id : null;
}

export const userController = {
  // Get fitness goals for the current user, with preferredWorkouts populated
  getFitnessGoals: async (req: Request, res: Response) => {
    const userId = getUserIdFromRequest(req);
    if (!userId) return ApiResponse.error(res, "Unauthorized", 401);

    try {
      const user = await User.findById(userId)
        .select(
          "healthGoals workoutFrequency preferredWorkouts preferredWorkoutTime"
        )
        .populate({ path: "preferredWorkouts", select: "_id name" }) // Populate _id and name for preferredWorkouts
        .populate({ path: "healthGoals", select: "_id name" }) // Populate _id and name for healthGoals
        .populate({ path: "workoutFrequency", select: "_id name" }); // Populate _id and name for workoutFrequency

      if (!user) return ApiResponse.error(res, "User not found", 404);

      // Map populated fields to their _id and name for consistency, or just the populated object
      const formattedUserGoals = {
        healthGoals: user.healthGoals
          ? {
              id: (user.healthGoals as any)._id,
              name: (user.healthGoals as any).name,
            }
          : null,
        workoutFrequency: user.workoutFrequency
          ? {
              id: (user.workoutFrequency as any)._id,
              name: (user.workoutFrequency as any).name,
            }
          : null,
        preferredWorkouts: ((user.preferredWorkouts as any[]) || []).map(
          (w: any) => ({ id: w._id, name: w.name })
        ),
        preferredWorkoutTime: user.preferredWorkoutTime,
      };

      return ApiResponse.success(
        res,
        formattedUserGoals,
        "Fitness goals fetched"
      );
    } catch (error: any) {
      console.error("Error fetching fitness goals:", error);
      return ApiResponse.error(
        res,
        "Failed to fetch fitness goals: " + error.message,
        500
      );
    }
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

    // Ensure preferredWorkouts are an array of ObjectIds (strings)
    if (update.preferredWorkouts) {
      update.preferredWorkouts = update.preferredWorkouts.map(
        (id: any) => (typeof id === "string" ? id : id._id) // Handles both direct IDs and populated objects from frontend
      );
    }

    try {
      const user = await User.findByIdAndUpdate(userId, update, {
        new: true,
        runValidators: true,
      })
        .select(
          "healthGoals workoutFrequency preferredWorkouts preferredWorkoutTime"
        )
        .populate({ path: "preferredWorkouts", select: "_id name" })
        .populate({ path: "healthGoals", select: "_id name" })
        .populate({ path: "workoutFrequency", select: "_id name" });

      if (!user) return ApiResponse.error(res, "User not found", 404);

      const formattedUserGoals = {
        healthGoals: user.healthGoals
          ? {
              id: (user.healthGoals as any)._id,
              name: (user.healthGoals as any).name,
            }
          : null,
        workoutFrequency: user.workoutFrequency
          ? {
              id: (user.workoutFrequency as any)._id,
              name: (user.workoutFrequency as any).name,
            }
          : null,
        preferredWorkouts: ((user.preferredWorkouts as any[]) || []).map(
          (w: any) => ({ id: w._id, name: w.name })
        ),
        preferredWorkoutTime: user.preferredWorkoutTime,
      };

      return ApiResponse.success(
        res,
        formattedUserGoals,
        "Fitness goals updated"
      );
    } catch (error: any) {
      console.error("Error updating fitness goals:", error);
      return ApiResponse.error(
        res,
        "Failed to update fitness goals: " + error.message,
        500
      );
    }
  },

  //Get all health goal options
  getHealthGoalsOptions: async (req: Request, res: Response) => {
    const userId = getUserIdFromRequest(req); // Still require auth for member options
    if (!userId) return ApiResponse.error(res, "Unauthorized", 401);
    try {
      const goals = await HealthGoal.find({}, "_id name"); // Select only _id and name
      return ApiResponse.success(
        res,
        goals.map((g) => ({ id: g._id, name: g.name })),
        "Health goals options fetched"
      );
    } catch (error: any) {
      console.error("Error fetching health goals options:", error);
      return ApiResponse.error(
        res,
        "Failed to fetch health goals options: " + error.message,
        500
      );
    }
  },

  //  Get all workout frequency options
  getWorkoutFrequencyOptions: async (req: Request, res: Response) => {
    const userId = getUserIdFromRequest(req);
    if (!userId) return ApiResponse.error(res, "Unauthorized", 401);
    try {
      const frequencies = await WorkoutFrequency.find({}, "_id name"); // Select only _id and name
      return ApiResponse.success(
        res,
        frequencies.map((f) => ({ id: f._id, name: f.name })),
        "Workout frequency options fetched"
      );
    } catch (error: any) {
      console.error("Error fetching workout frequency options:", error);
      return ApiResponse.error(
        res,
        "Failed to fetch workout frequency options: " + error.message,
        500
      );
    }
  },

  // Search and get workout options
  searchWorkouts: async (req: Request, res: Response) => {
    const userId = getUserIdFromRequest(req);
    if (!userId) return ApiResponse.error(res, "Unauthorized", 401);

    const searchQuery = (req.query.search as string) || "";
    const limit = parseInt(req.query.limit as string) || 10; // Default limit
    const page = parseInt(req.query.page as string) || 1; // Default page
    const skip = (page - 1) * limit;

    try {
      const queryFilter = searchQuery
        ? { name: { $regex: searchQuery, $options: "i" } } // Case-insensitive search by name
        : {};

      const workouts = await Workout.find(queryFilter, "_id name") // Select only _id and name
        .skip(skip)
        .limit(limit);

      return ApiResponse.success(
        res,
        workouts.map((w) => ({ id: w._id, name: w.name })),
        "Workouts fetched"
      );
    } catch (error: any) {
      console.error("Error searching workouts:", error);
      return ApiResponse.error(
        res,
        "Failed to search workouts: " + error.message,
        500
      );
    }
  },
  /**
   * This method fetches the full user profile for the logged-in user.
   * It includes all user details except the password, and populates related fields
   * @param req Request object containing user decoded from JWT
   * @param res
   * @returns Full user profile with populated fields
   */
  getProfile: async (req: Request, res: Response) => {
    const userId = getUserIdFromRequest(req);
    if (!userId) return ApiResponse.error(res, "Unauthorized", 401);
    const user = await User.findById(userId)
      .select("-password")
      .populate("healthGoals workoutFrequency preferredWorkouts");
    if (!user) return ApiResponse.error(res, "User not found", 404);

    const formattedUserProfile = {
      personal: {
        name: user.name,
        email: user.email,
        phone: user.phone,
        avatarUrl: user.avatarUrl,
        dob: user.dob,
        gender: user.gender,
        height: user.height,
        weight: user.weight,
        bio: user.bio,
      },
      fitness: {
        healthGoals:
          typeof user.healthGoals === "object" &&
          user.healthGoals !== null &&
          "name" in user.healthGoals
            ? (user.healthGoals as any).name
            : user.healthGoals,
        workoutFrequency:
          typeof user.workoutFrequency === "object" &&
          user.workoutFrequency !== null &&
          "name" in user.workoutFrequency
            ? (user.workoutFrequency as any).name
            : user.workoutFrequency,
        preferredWorkouts: Array.isArray(user.preferredWorkouts)
          ? user.preferredWorkouts.map((w) =>
              typeof w === "object" && w !== null && "name" in w
                ? (w as any).name
                : w
            )
          : [],
        preferredWorkoutTime: user.preferredWorkoutTime,
      },
      payment: { status: "Active", method: "Mastercard **** 56780" },
    };

    return ApiResponse.success(res, formattedUserProfile, "Profile fetched");
  },
  getPersonalInfo: async (req: Request, res: Response) => {
    // This method is for fetching the personal profile of the logged-in user for edit personal details screen
    const userId = getUserIdFromRequest(req);
    if (!userId) return ApiResponse.error(res, "Unauthorized", 401);
    const user = await User.findById(userId).select([
      "-_id",
      "name",
      "email",
      "phone",
      "avatarUrl",
      "dob",
      "gender",
      "height",
      "weight",
      "bio",
    ]);

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
