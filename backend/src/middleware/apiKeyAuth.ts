import { Request, Response, NextFunction } from 'express';
import { AUTH_KEY } from '../constants/auth';

export function apiKeyAuth(req: Request, res: Response, next: NextFunction) {
  const apiKey = req.headers[AUTH_KEY.toLowerCase()] || req.headers['x-api-key'];
  if (!apiKey || apiKey !== process.env.AUTH_KEY) {
    return res.status(401).json({ message: 'Invalid or missing API key' });
  }
  next();
}
