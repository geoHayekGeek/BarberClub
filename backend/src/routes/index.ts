/**
 * Main router
 * Mounts all route modules
 */

import { Router } from 'express';
import authRoutes from './auth';
import bookingRoutes from './booking';
import bookingsRoutes from './bookings';
import loyaltyRoutes from './loyalty';
import offersRoutes from './offers';
import salonsRoutes from './salons';
import barbersRoutes from './barbers';
import devRoutes from './dev';
import adminRoutes from './admin';

const router = Router();

router.use('/auth', authRoutes);
router.use('/booking', bookingRoutes);
router.use('/bookings', bookingsRoutes);
router.use('/loyalty', loyaltyRoutes);
router.use('/offers', offersRoutes);
router.use('/salons', salonsRoutes);
router.use('/barbers', barbersRoutes);
router.use('/dev', devRoutes);
router.use('/admin', adminRoutes);

export default router;
