import request from 'supertest';
import app from '../src/server';
import { signJwt } from '../src/utils/jwt';
import { ROLES } from '../src/constants/roles';

describe('Trainer API', () => {
  let trainerToken: string;

  beforeAll(() => {
    trainerToken = signJwt({ _id: 'trainerid', role: ROLES.TRAINER });
  });

  it('should get assigned users', async () => {
    const res = await request(app)
      .get('/api/trainer/assigned-users')
      .set('Authorization', `Bearer ${trainerToken}`);
    expect(res.status).toBe(200);
  });

  // Add more tests for assignWorkout, assignDiet as needed
});
