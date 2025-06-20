import request from 'supertest';
import app from '../src/server';
import { signJwt } from '../src/utils/jwt';
import { ROLES } from '../src/constants/roles';

describe('User API', () => {
  let userToken: string;

  beforeAll(() => {
    userToken = signJwt({ _id: 'userid', role: ROLES.USER });
  });

  it('should get user profile', async () => {
    const res = await request(app)
      .get('/api/user/me')
      .set('Authorization', `Bearer ${userToken}`);
    expect(res.status).toBe(200);
  });

  // Add more tests for workout, diet, payments, performance as needed
});
