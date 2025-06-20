import { Request, Response } from "express";
import ApiResponse from "../utils/api_response";
import User from "../models/user";
import Trainer from "../models/trainer";
import PaymentHistory from "../models/payment-history";
import { revokeToken } from "../utils/revokeTokenStore";

export const adminController = {
  // Get all users
  getAllUsers: async (req: Request, res: Response) => {
    const users = await User.find().select("-password");
    return ApiResponse.success(res, users);
  },

  // Get all trainers
  getAllTrainers: async (req: Request, res: Response) => {
    const trainers = await Trainer.find().select("-password");
    return ApiResponse.success(res, trainers);
  },

  // Assign or replace trainer for a user
  assignTrainer: async (req: Request, res: Response) => {
    const { userId, trainerId } = req.body;
    const user = await User.findByIdAndUpdate(
      userId,
      { trainerId },
      { new: true }
    );
    return ApiResponse.success(res, { user });
  },

  // View all payment records
  getAllPayments: async (req: Request, res: Response) => {
    const payments = await PaymentHistory.find();
    return ApiResponse.success(res, payments);
  },

  // Revoke a user's JWT
  revokeUserToken: async (req: Request, res: Response) => {
    const { token } = req.body;
    await revokeToken(token);
    return ApiResponse.success(res, { message: "Token revoked" });
  },
};
