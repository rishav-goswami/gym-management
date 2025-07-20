import { Response } from "express";
import { ZodError } from "zod";

class ApiResponse {
  static success(
    res: Response,
    data: object | null = {},
    message = "Request successful",
    statusCode = 200
  ) {
    return res.status(statusCode).json({
      success: true,
      message,
      data,
      statusCode,
      timestamp: new Date().toISOString(),
    });
  }

  static error(
    res: Response,
    message = "Something went wrong",
    statusCode = 500,
    error: Error | null = null
  ) {
    return res.status(statusCode).json({
      success: false,
      message,
      error: error ? this.formatError(error) : null,
      statusCode,
      timestamp: new Date().toISOString(),
    });
  }

  static validationError(
    res: Response,
    zodError: ZodError,
    message = "Validation failed",
    statusCode = 400
  ) {
    const formattedErrors = this.formatZodError(zodError);
    return res.status(statusCode).json({
      success: false,
      message,
      errors: formattedErrors,
      statusCode,
      timestamp: new Date().toISOString(),
    });
  }

  static unauthorized(
    res: Response,
    message = "Unauthorized",
    statusCode = 401
  ) {
    return this.error(res, message, statusCode);
  }

  static notFound(
    res: Response,
    message = "Resource not found",
    statusCode = 404
  ) {
    return this.error(res, message, statusCode);
  }

  static formatError(error: Error) {
    if (typeof error === "string") {
      return error;
    } else if (error instanceof Error) {
      return error.message;
    } else if (typeof error === "object") {
      return error;
    } else {
      return "Unknown error";
    }
  }

  static formatZodError(zodError: ZodError) {
    if (!(zodError instanceof ZodError)) {
      return "Invalid validation error object";
    }

    return zodError.errors.map((err) => {
      return {
        path: err.path.join("."),
        message: err.message,
      };
    });
  }
}

export default ApiResponse;
