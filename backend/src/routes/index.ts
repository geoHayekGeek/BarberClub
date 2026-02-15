/**
 * Main router
 * Mounts all route modules
 */

import { Router } from 'express';
import authRoutes from './auth';
import usersRoutes from './users';
import loyaltyRoutes from './loyalty';
import offersRoutes from './offers';
import salonsRoutes from './salons';
import barbersRoutes from './barbers';
import devRoutes from './dev';
import adminRoutes from './admin';

const router = Router();

router.use('/auth', authRoutes);
router.use('/users', usersRoutes);
router.use('/loyalty', loyaltyRoutes);
router.use('/offers', offersRoutes);
router.use('/salons', salonsRoutes);
router.use('/barbers', barbersRoutes);
router.use('/dev', devRoutes);
router.use('/admin', adminRoutes);

export default router;
