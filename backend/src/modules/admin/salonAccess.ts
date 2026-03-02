import prisma from '../../db/client';
import { AppError, ErrorCode } from '../../utils/errors';
import { logger } from '../../utils/logger';

/**
 * Ensure that an admin has access to a given salon.
 * - Super admins (isSuperAdmin) bypass salon checks.
 * - Non-super admins must be linked to at least one salon and specifically to salonId.
 */
export async function assertAdminHasAccessToSalon(adminUserId: string, salonId: string): Promise<void> {
  const admin = await prisma.user.findUnique({
    where: { id: adminUserId },
    select: {
      id: true,
      role: true,
      isSuperAdmin: true,
      adminSalons: { select: { id: true } },
    },
  });

  if (!admin) {
    throw new AppError(ErrorCode.FORBIDDEN, 'Forbidden', 403);
  }

  if (admin.role !== 'ADMIN') {
    throw new AppError(ErrorCode.FORBIDDEN, 'Forbidden', 403);
  }

  if (admin.isSuperAdmin) {
    return;
  }

  if (!admin.adminSalons.length) {
    logger.warn('SALON_ACCESS_DENIED no_salon', { adminId: admin.id, salonId });
    throw new AppError(ErrorCode.SALON_ACCESS_DENIED, 'Accès salon refusé', 403);
  }

  const hasAccess = admin.adminSalons.some((s) => s.id === salonId);
  if (!hasAccess) {
    logger.warn('SALON_ACCESS_DENIED', { adminId: admin.id, salonId });
    throw new AppError(ErrorCode.SALON_ACCESS_DENIED, 'Accès salon refusé', 403);
  }
}

