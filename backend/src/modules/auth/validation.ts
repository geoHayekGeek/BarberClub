/**
 * Zod validation schemas for auth endpoints
 */

import { z } from 'zod';

// ... (keep your existing registerSchema, loginSchema, etc.) ...
export const registerSchema = z.object({
  email: z.string().email('Invalid email format').toLowerCase().trim(),
  phoneNumber: z.string().min(1, 'Phone number is required'),
  password: z.string().min(8, 'Password must be at least 8 characters'),
  fullName: z.string().optional(),
});

export const loginSchema = z.object({
  email: z.string().optional(),
  phoneNumber: z.string().optional(),
  password: z.string().min(1, 'Password is required'),
}).refine(
  (data) => data.email || data.phoneNumber,
  {
    message: 'Either email or phoneNumber must be provided',
    path: ['email'],
  }
);

export const refreshSchema = z.object({
  refreshToken: z.string().min(1, 'Refresh token is required'),
});

export const forgotPasswordSchema = z.object({
  email: z.string().email('Invalid email format').toLowerCase().trim(),
});

export const resetPasswordSchema = z.object({
  email: z.string().email('Invalid email format').toLowerCase().trim(),
  code: z.string().regex(/^\d{6}$/, 'Code must be exactly 6 digits'),
  newPassword: z.string().min(8, 'Password must be at least 8 characters'),
});

// --- NEW SCHEMAS ---

export const updateProfileSchema = z.object({
  email: z.string().email('Format email invalide').toLowerCase().trim().optional(),
  phoneNumber: z.string().min(1, 'Numéro de téléphone invalide').optional(),
  fullName: z.string().min(1, 'Nom complet invalide').optional(),
});

export const changePasswordSchema = z.object({
  oldPassword: z.string().min(1, 'L\'ancien mot de passe est requis'),
  newPassword: z.string().min(8, 'Le nouveau mot de passe doit faire 8 caractères min.'),
});