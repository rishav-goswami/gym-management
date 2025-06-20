import { Request, Response } from "express";
import bcrypt from "bcryptjs";
import jwt from "jsonwebtoken";
import { z } from "zod";
import ApiResponse from "../utils/api_response";
import User, { IUser } from "../models/user";
import { revokeToken } from "../utils/revokeTokenStore";
import Trainer, { ITrainer } from "../models/trainer";
import Admin, { IAdmin } from "../models/admin";
import { signJwt } from "../utils/jwt";
// import "../types/express"; // Ensure the augmentation is loaded

declare global {
  namespace Express {
    interface Request {
      user?: Object | any;
    }
  }
}

interface JwtUser {
  _id: string;
  email: string;
  [key: string]: any;
}

const registerSchema = z
  .object({
    name: z.string().min(2, "Name is required"),
    email: z.string().email("Invalid email"),
    password: z.string().min(6, "Password must be at least 6 characters"),
    confirmPassword: z
      .string()
      .min(6, "Password must be at least 6 characters"),
  })
  .refine((data) => data.password === data.confirmPassword, {
    message: "Passwords do not match",
    path: ["confirmPassword"],
  });

const loginSchema = z.object({
  email: z.string().email("Invalid email"),
  password: z.string().min(6, "Password must be at least 6 characters"),
  role: z.enum(["ADMIN", "USER", "TRAINER"]),
});

export const authController = {
  register: async (req: Request, res: Response): Promise<Response> => {
    try {
      const parsed = registerSchema.safeParse(req.body);
      if (!parsed.success) {
        return ApiResponse.validationError(
          res,
          parsed.error,
          "Validation failed"
        );
      }

      const { name, email, password } = parsed.data;

      const existingUser = await User.findOne({ email });
      if (existingUser) {
        return ApiResponse.error(res, "Email already registered", 409);
      }

      const hashedPassword = await bcrypt.hash(password, 10);

      const newUser = new User({
        name,
        email,
        password: hashedPassword,
      });

      await newUser.save();

      return ApiResponse.success(
        res,
        { id: newUser._id, email: newUser.email, name: newUser.name },
        "User registered successfully",
        201
      );
    } catch (error) {
      return ApiResponse.error(res, "Registration failed", 500, error as Error);
    }
  },

  login: async (req: Request, res: Response): Promise<Response> => {
    try {
      const parsed = loginSchema.safeParse(req.body);
      if (!parsed.success) {
        return ApiResponse.validationError(
          res,
          parsed.error,
          "Validation failed"
        );
      }

      const { email, password, role } = parsed.data;

      let user:
        | (typeof User extends { prototype: infer U } ? U : never)
        | (typeof Admin extends { prototype: infer A } ? A : never)
        | (typeof Trainer extends { prototype: infer T } ? T : never)
        | null = null;

      // Fetch user based on role
      if (role === "USER") {
        user = await User.findOne({ email });
      } else if (role === "TRAINER") {
        user = await Trainer.findOne({ email });
      } else if (role === "ADMIN") {
        user = await Admin.findOne({ email });
      }

      if (!user) {
        return ApiResponse.error(res, "No user found!", 401);
      }

      const isMatch = await user.comparePassword(password);
      if (!isMatch) {
        return ApiResponse.error(res, "Invalid credentials", 401);
      }

      // Token payload type-safe
      const token = signJwt({
        id: user._id.toString(),
        email: user.email,
        role,
      });

      return ApiResponse.success(
        res,
        {
          token,
          user: {
            id: user._id,
            name: user.name,
            email: user.email,
            role,
          },
        },
        "User logged in successfully"
      );
    } catch (error) {
      return ApiResponse.error(res, "Login failed", 500, error as Error);
    }
  },

  logout: async (_req: Request, res: Response): Promise<Response> => {
    // Token-based auth doesn't need server-side logout unless using refresh tokens
    return ApiResponse.success(res, {}, "User logged out successfully");
  },

  revokeJwt: async (req: Request, res: Response): Promise<Response> => {
    const authHeader = req.headers["authorization"];
    if (!authHeader || !authHeader.startsWith("Bearer ")) {
      return ApiResponse.error(res, "No token provided", 401);
    }
    const token = authHeader.split(" ")[1];
    // Assuming a JWT middleware attaches user info to req.user
    const user = req.user as JwtUser | undefined;
    const userId = user ? user._id : undefined;
    if (!userId) {
      return ApiResponse.error(res, "User not authenticated", 401);
    }
    await revokeToken(token, userId);
    return ApiResponse.success(res, {}, "Token revoked successfully");
  },
};
