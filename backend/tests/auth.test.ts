/**
 * Authentication endpoint tests
 */

import request from 'supertest';
import { createApp } from '../src/app';
import prisma from '../src/db/client';

beforeAll(async () => {
  await prisma.$connect();
  // Clean up all data before starting tests
  await prisma.passwordResetToken.deleteMany();
  await prisma.timifyReservation.deleteMany();
  await prisma.booking.deleteMany();
  await prisma.refreshToken.deleteMany();
  await prisma.user.deleteMany();
});

afterAll(async () => {
  // Clean up all data after tests
  await prisma.passwordResetToken.deleteMany();
  await prisma.timifyReservation.deleteMany();
  await prisma.booking.deleteMany();
  await prisma.refreshToken.deleteMany();
  await prisma.user.deleteMany();
  await prisma.$disconnect();
});

const app = createApp();

describe('POST /api/v1/auth/register', () => {
  beforeEach(async () => {
    await prisma.passwordResetToken.deleteMany();
    await prisma.timifyReservation.deleteMany();
    await prisma.booking.deleteMany();
    await prisma.refreshToken.deleteMany();
    await prisma.user.deleteMany();
  });

  it('should register a new user successfully', async () => {
    const response = await request(app)
      .post('/api/v1/auth/register')
      .send({
        email: 'test@example.com',
        phoneNumber: '+1234567890',
        password: 'password123',
        fullName: 'Test User',
      });

    expect(response.status).toBe(201);
    expect(response.body).toHaveProperty('user');
    expect(response.body).toHaveProperty('accessToken');
    expect(response.body).toHaveProperty('refreshToken');
    expect(response.body.user.email).toBe('test@example.com');
    expect(response.body.user.phoneNumber).toBe('+1234567890');
    expect(response.body.user.fullName).toBe('Test User');
    expect(response.body.user).not.toHaveProperty('passwordHash');
  });

  it('should return 400 for invalid email', async () => {
    const response = await request(app)
      .post('/api/v1/auth/register')
      .send({
        email: 'invalid-email',
        phoneNumber: '+1234567890',
        password: 'password123',
      });

    expect(response.status).toBe(400);
    expect(response.body.error).toHaveProperty('code');
    expect(response.body.error.code).toBe('VALIDATION_ERROR');
  });

  it('should return 400 for short password', async () => {
    const response = await request(app)
      .post('/api/v1/auth/register')
      .send({
        email: 'test@example.com',
        phoneNumber: '+1234567890',
        password: 'short',
      });

    expect(response.status).toBe(400);
    expect(response.body.error.code).toBe('VALIDATION_ERROR');
  });

  it('should return 409 for duplicate email', async () => {
    await request(app)
      .post('/api/v1/auth/register')
      .send({
        email: 'duplicate@example.com',
        phoneNumber: '+1234567890',
        password: 'password123',
      });

    const response = await request(app)
      .post('/api/v1/auth/register')
      .send({
        email: 'duplicate@example.com',
        phoneNumber: '+1987654321',
        password: 'password123',
      });

    expect(response.status).toBe(409);
    expect(response.body.error.code).toBe('USER_ALREADY_EXISTS');
    expect(response.body.error.fields).toHaveProperty('email');
    expect(response.body.error.fields.email).toBe(true);
  });

  it('should return 409 for duplicate phoneNumber', async () => {
    await request(app)
      .post('/api/v1/auth/register')
      .send({
        email: 'user1@example.com',
        phoneNumber: '+1999999999',
        password: 'password123',
      });

    const response = await request(app)
      .post('/api/v1/auth/register')
      .send({
        email: 'user2@example.com',
        phoneNumber: '+1999999999',
        password: 'password123',
      });

    expect(response.status).toBe(409);
    expect(response.body.error.code).toBe('USER_ALREADY_EXISTS');
    expect(response.body.error.fields).toHaveProperty('phoneNumber');
    expect(response.body.error.fields.phoneNumber).toBe(true);
  });

  it('should return 409 with both fields when email and phoneNumber are duplicates', async () => {
    await request(app)
      .post('/api/v1/auth/register')
      .send({
        email: 'both@example.com',
        phoneNumber: '+1888888888',
        password: 'password123',
      });

    const response = await request(app)
      .post('/api/v1/auth/register')
      .send({
        email: 'both@example.com',
        phoneNumber: '+1888888888',
        password: 'password123',
      });

    expect(response.status).toBe(409);
    expect(response.body.error.code).toBe('USER_ALREADY_EXISTS');
    expect(response.body.error.fields).toHaveProperty('email');
    expect(response.body.error.fields).toHaveProperty('phoneNumber');
    expect(response.body.error.fields.email).toBe(true);
    expect(response.body.error.fields.phoneNumber).toBe(true);
  });

  it('should prevent registering with same phoneNumber and different email', async () => {
    await request(app)
      .post('/api/v1/auth/register')
      .send({
        email: 'original@example.com',
        phoneNumber: '+1777777777',
        password: 'password123',
      });

    const response = await request(app)
      .post('/api/v1/auth/register')
      .send({
        email: 'different@example.com',
        phoneNumber: '+1777777777',
        password: 'password123',
      });

    expect(response.status).toBe(409);
    expect(response.body.error.code).toBe('USER_ALREADY_EXISTS');
    expect(response.body.error.fields).toHaveProperty('phoneNumber');
    expect(response.body.error.fields.phoneNumber).toBe(true);
  });
});

describe('POST /api/v1/auth/login', () => {
  beforeEach(async () => {
    await prisma.passwordResetToken.deleteMany();
    await prisma.timifyReservation.deleteMany();
    await prisma.booking.deleteMany();
    await prisma.refreshToken.deleteMany();
    await prisma.user.deleteMany();

    await request(app)
      .post('/api/v1/auth/register')
      .send({
        email: 'login@example.com',
        phoneNumber: '+1111111111',
        password: 'password123',
      });
  });

  it('should login with email successfully', async () => {
    const response = await request(app)
      .post('/api/v1/auth/login')
      .send({
        email: 'login@example.com',
        password: 'password123',
      });

    expect(response.status).toBe(200);
    expect(response.body).toHaveProperty('accessToken');
    expect(response.body).toHaveProperty('refreshToken');
    expect(response.body.user.email).toBe('login@example.com');
  });

  it('should login with phone number successfully', async () => {
    const response = await request(app)
      .post('/api/v1/auth/login')
      .send({
        phoneNumber: '+1111111111',
        password: 'password123',
      });

    expect(response.status).toBe(200);
    expect(response.body).toHaveProperty('accessToken');
    expect(response.body).toHaveProperty('refreshToken');
  });

  it('should return 401 for invalid password', async () => {
    const response = await request(app)
      .post('/api/v1/auth/login')
      .send({
        email: 'login@example.com',
        password: 'wrongpassword',
      });

    expect(response.status).toBe(401);
    expect(response.body.error.code).toBe('INVALID_CREDENTIALS');
  });

  it('should return 401 for non-existent user', async () => {
    const response = await request(app)
      .post('/api/v1/auth/login')
      .send({
        email: 'nonexistent@example.com',
        password: 'password123',
      });

    expect(response.status).toBe(401);
    expect(response.body.error.code).toBe('INVALID_CREDENTIALS');
  });
});

describe('GET /api/v1/auth/me', () => {
  let accessToken: string;

  beforeAll(async () => {
    await prisma.passwordResetToken.deleteMany();
    await prisma.timifyReservation.deleteMany();
    await prisma.booking.deleteMany();
    await prisma.refreshToken.deleteMany();
    await prisma.user.deleteMany();

    const registerResponse = await request(app)
      .post('/api/v1/auth/register')
      .send({
        email: 'me@example.com',
        phoneNumber: '+2222222222',
        password: 'password123',
        fullName: 'Me User',
      });

    accessToken = registerResponse.body.accessToken;
  });

  afterAll(async () => {
    await prisma.passwordResetToken.deleteMany();
    await prisma.timifyReservation.deleteMany();
    await prisma.booking.deleteMany();
    await prisma.refreshToken.deleteMany();
    await prisma.user.deleteMany();
  });

  it('should return current user profile', async () => {
    const response = await request(app)
      .get('/api/v1/auth/me')
      .set('Authorization', `Bearer ${accessToken}`);

    expect(response.status).toBe(200);
    expect(response.body).toHaveProperty('user');
    expect(response.body.user.email).toBe('me@example.com');
    expect(response.body.user.fullName).toBe('Me User');
  });

  it('should return 401 without token', async () => {
    const response = await request(app)
      .get('/api/v1/auth/me');

    expect(response.status).toBe(401);
    expect(response.body.error.code).toBe('UNAUTHORIZED');
  });

  it('should return 401 with invalid token', async () => {
    const response = await request(app)
      .get('/api/v1/auth/me')
      .set('Authorization', 'Bearer invalid-token');

    expect(response.status).toBe(401);
  });
});

describe('POST /api/v1/auth/forgot-password', () => {
  beforeEach(async () => {
    await prisma.passwordResetToken.deleteMany();
    await prisma.timifyReservation.deleteMany();
    await prisma.booking.deleteMany();
    await prisma.refreshToken.deleteMany();
    await prisma.user.deleteMany();
  });

  it('should return 200 for existing email', async () => {
    await request(app)
      .post('/api/v1/auth/register')
      .send({
        email: 'forgot@example.com',
        phoneNumber: '+3333333333',
        password: 'password123',
      });

    const response = await request(app)
      .post('/api/v1/auth/forgot-password')
      .send({
        email: 'forgot@example.com',
      });

    expect(response.status).toBe(200);
    expect(response.body.message).toContain('password reset link has been sent');
  });

  it('should return 200 for non-existing email', async () => {
    const response = await request(app)
      .post('/api/v1/auth/forgot-password')
      .send({
        email: 'nonexistent@example.com',
      });

    expect(response.status).toBe(200);
    expect(response.body.message).toContain('password reset link has been sent');
  });

  it('should create password reset token for existing user', async () => {
    const registerResponse = await request(app)
      .post('/api/v1/auth/register')
      .send({
        email: 'token@example.com',
        phoneNumber: '+4444444444',
        password: 'password123',
      });

    const userId = registerResponse.body.user.id;

    await request(app)
      .post('/api/v1/auth/forgot-password')
      .send({
        email: 'token@example.com',
      });

    const resetToken = await prisma.passwordResetToken.findFirst({
      where: { userId },
    });

    expect(resetToken).toBeTruthy();
    expect(resetToken?.usedAt).toBeNull();
    expect(resetToken?.expiresAt.getTime()).toBeGreaterThan(Date.now());
  });
});

describe('POST /api/v1/auth/reset-password', () => {
  let user: { id: string; email: string };
  let resetToken: string;

  beforeEach(async () => {
    await prisma.passwordResetToken.deleteMany();
    await prisma.timifyReservation.deleteMany();
    await prisma.booking.deleteMany();
    await prisma.refreshToken.deleteMany();
    await prisma.user.deleteMany();

    const registerResponse = await request(app)
      .post('/api/v1/auth/register')
      .send({
        email: 'reset@example.com',
        phoneNumber: '+5555555555',
        password: 'oldpassword123',
      });

    user = registerResponse.body.user;

    const forgotResponse = await request(app)
      .post('/api/v1/auth/forgot-password')
      .send({
        email: 'reset@example.com',
      });

    expect(forgotResponse.status).toBe(200);

    const emailsResponse = await request(app).get('/api/v1/dev/emails');
    const emails = emailsResponse.body.emails;
    const email = emails.find((e: { to: string }) => e.to === 'reset@example.com');
    expect(email).toBeTruthy();
    expect(email.html).toBeDefined();

    const resetUrlMatch = email.html.match(/reset-password-redirect\?token=([^&"'\s<>]+)/);
    expect(resetUrlMatch).toBeTruthy();
    expect(resetUrlMatch).toHaveLength(2);
    resetToken = decodeURIComponent(resetUrlMatch![1]);
    expect(resetToken).toBeTruthy();
    expect(resetToken.length).toBeGreaterThan(0);
  });

  afterAll(async () => {
    await prisma.passwordResetToken.deleteMany();
    await prisma.timifyReservation.deleteMany();
    await prisma.booking.deleteMany();
    await prisma.refreshToken.deleteMany();
    await prisma.user.deleteMany();
  });

  it('should reset password with valid token', async () => {
    const forgotResponse = await request(app)
      .post('/api/v1/auth/forgot-password')
      .send({
        email: 'reset@example.com',
      });

    expect(forgotResponse.status).toBe(200);

    const emailsResponse = await request(app).get('/api/v1/dev/emails');
    const emails = emailsResponse.body.emails;
    const resetEmails = emails.filter((e: { to: string }) => e.to === 'reset@example.com');
    expect(resetEmails.length).toBeGreaterThan(0);
    const email = resetEmails[resetEmails.length - 1];

    const resetUrlMatch = email.html.match(/reset-password-redirect\?token=([^&"'\s<>]+)/);
    expect(resetUrlMatch).toBeTruthy();
    const testToken = decodeURIComponent(resetUrlMatch![1]);

    const response = await request(app)
      .post('/api/v1/auth/reset-password')
      .send({
        email: 'reset@example.com',
        token: testToken,
        newPassword: 'newpassword123',
      });

    expect(response.status).toBe(200);
    expect(response.body.message).toBe('Password reset successfully');

    const loginResponse = await request(app)
      .post('/api/v1/auth/login')
      .send({
        email: 'reset@example.com',
        password: 'newpassword123',
      });

    expect(loginResponse.status).toBe(200);
  });

  it('should fail with invalid token', async () => {
    const response = await request(app)
      .post('/api/v1/auth/reset-password')
      .send({
        email: 'reset@example.com',
        token: 'invalid-token',
        newPassword: 'newpassword123',
      });

    expect(response.status).toBe(401);
    expect(response.body.error.code).toBe('TOKEN_INVALID');
  });

  it('should fail with expired token', async () => {
    const tokenRecord = await prisma.passwordResetToken.findFirst({
      where: { userId: user.id },
    });

    if (tokenRecord) {
      await prisma.passwordResetToken.update({
        where: { id: tokenRecord.id },
        data: { expiresAt: new Date(Date.now() - 1000) },
      });
    }

    const response = await request(app)
      .post('/api/v1/auth/reset-password')
      .send({
        email: 'reset@example.com',
        token: resetToken,
        newPassword: 'newpassword123',
      });

    expect(response.status).toBe(401);
    expect(response.body.error.code).toBe('TOKEN_INVALID');
  });

  it('should fail with used token', async () => {
    // Create a fresh user for this test to ensure isolation
    const registerResponse = await request(app)
      .post('/api/v1/auth/register')
      .send({
        email: 'usedtoken@example.com',
        phoneNumber: '+9999999999',
        password: 'oldpassword123',
      });

    expect(registerResponse.status).toBe(201);

    const usedTokenResponse = await request(app)
      .post('/api/v1/auth/forgot-password')
      .send({
        email: 'usedtoken@example.com',
      });

    expect(usedTokenResponse.status).toBe(200);

    const emailsResponse = await request(app).get('/api/v1/dev/emails');
    const emails = emailsResponse.body.emails;
    const resetEmails = emails.filter((e: { to: string }) => e.to === 'usedtoken@example.com');
    expect(resetEmails.length).toBeGreaterThan(0);
    const email = resetEmails[resetEmails.length - 1];

    const resetUrlMatch = email.html.match(/reset-password-redirect\?token=([^&"'\s<>]+)/);
    expect(resetUrlMatch).toBeTruthy();
    const usedToken = decodeURIComponent(resetUrlMatch![1]);
    expect(usedToken).toBeTruthy();

    const firstResponse = await request(app)
      .post('/api/v1/auth/reset-password')
      .send({
        email: 'usedtoken@example.com',
        token: usedToken,
        newPassword: 'newpassword123',
      });

    expect(firstResponse.status).toBe(200);

    const response = await request(app)
      .post('/api/v1/auth/reset-password')
      .send({
        email: 'usedtoken@example.com',
        token: usedToken,
        newPassword: 'anotherpassword123',
      });

    expect(response.status).toBe(401);
    expect(response.body.error.code).toBe('TOKEN_INVALID');
  });

  it('should revoke all refresh tokens after password reset', async () => {
    const loginResponse = await request(app)
      .post('/api/v1/auth/login')
      .send({
        email: 'reset@example.com',
        password: 'oldpassword123',
      });

    const refreshToken = loginResponse.body.refreshToken;

    await request(app)
      .post('/api/v1/auth/reset-password')
      .send({
        email: 'reset@example.com',
        token: resetToken,
        newPassword: 'newpassword123',
      });

    const refreshResponse = await request(app)
      .post('/api/v1/auth/refresh')
      .send({
        refreshToken,
      });

    expect(refreshResponse.status).toBe(401);
  });
});
