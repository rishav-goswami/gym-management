import RevokedToken from '../models/revoked-token';
import { ObjectId } from 'mongoose';

export async function revokeToken(token: string, userId?: string | ObjectId) {
  await RevokedToken.create({ token, userId });
}

export async function isTokenRevoked(token: string) {
  const found = await RevokedToken.findOne({ token });
  return !!found;
}
