import request from 'supertest';
import app from '../src/server';
import { signJwt } from '../src/utils/jwt';
import { ROLES } from '../src/constants/roles';

describe('Admin API', () => {
  let adminToken: string;

  beforeAll(() => {
    adminToken = signJwt({ _id: 'adminid', role: ROLES.ADMIN });
  });

  it('should get all users', async () => {
    const res = await request(app)
      .get('/api/admin/users')
      .set('Authorization', `Bearer ${adminToken}`);
    expect(res.status).toBe(200);
  });

  it('should get all trainers', async () => {
    const res = await request(app)
      .get('/api/admin/trainers')
      .set('Authorization', `Bearer ${adminToken}`);
    expect(res.status).toBe(200);
  });

  // Add more tests for assignTrainer, getAllPayments, revokeUserToken as needed
});
