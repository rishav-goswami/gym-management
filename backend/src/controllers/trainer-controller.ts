import { Request, Response } from 'express';
import ApiResponse from '../utils/api_response';
import User from '../models/user';
import WorkoutRoutine from '../models/workout-plan';
import DietPlan from '../models/diet-plan';

export const trainerController = {
  // Get assigned users
  getAssignedUsers: async (req: Request, res: Response) => {
    const trainerId = req.user._id;
    const users = await User.find({ trainerId });
    return ApiResponse.success(res, users);
  },

  // Assign or update workout plan
  assignWorkout: async (req: Request, res: Response) => {
    const { userId, days } = req.body;
    const routine = await WorkoutRoutine.findOneAndUpdate(
      { userId },
      { days, createdBy: req.user._id },
      { upsert: true, new: true }
    );
    return ApiResponse.success(res, routine);
  },

  // Assign or update diet plan
  assignDiet: async (req: Request, res: Response) => {
    const { userId, dayWiseDiet } = req.body;
    const diet = await DietPlan.findOneAndUpdate(
      { userId },
      { dayWiseDiet, createdBy: req.user._id },
      { upsert: true, new: true }
    );
    return ApiResponse.success(res, diet);
  },
};
