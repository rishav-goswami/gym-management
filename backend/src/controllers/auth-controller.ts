import { Request, Response } from "express";
import bcrypt from "bcryptjs";
import jwt from "jsonwebtoken";
import { z } from "zod";
import ApiResponse from "../utils/api_response";
import User from "../models/user";

const registerSchema = z
  .object({
    name: z.string().min(2, "Name is required"),
    email: z.string().email("Invalid email"),
    password: z.string().min(6, "Password must be at least 6 characters"),
    confirmPassword: z.string().min(6, "Password must be at least 6 characters"),
  })
  .refine((data) => data.password === data.confirmPassword, {
    message: "Passwords do not match",
    path: ["confirmPassword"],
  });

const loginSchema = z.object({
  email: z.string().email("Invalid email"),
  password: z.string().min(6, "Password must be at least 6 characters"),
});

export const authController = {
  register: async (req: Request, res: Response): Promise<Response> => {
    try {
      const parsed = registerSchema.safeParse(req.body);
      if (!parsed.success) {
        return ApiResponse.validationError(res, parsed.error, "Validation failed");
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
        return ApiResponse.validationError(res, parsed.error, "Validation failed");
      }

      const { email, password } = parsed.data;

      const user = await User.findOne({ email });
      if (!user) {
        return ApiResponse.error(res, "No user found !", 401);
      }

      const isMatch = await bcrypt.compare(password, user.password);
      if (!isMatch) {
        return ApiResponse.error(res, "Invalid credentials", 401);
      }

      const token = jwt.sign(
        { id: user._id, email: user.email },
        process.env.JWT_SECRET || "your_jwt_secret",
        { expiresIn: "1h" }
      );

      return ApiResponse.success(
        res,
        {
          token,
          user: {
            id: user._id,
            email: user.email,
            name: user.name,
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
};
