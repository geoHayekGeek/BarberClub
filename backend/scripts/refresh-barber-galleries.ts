/**
 * One-off script to refresh barbers' `gallery` field from the photos currently
 * present on disk under public/images/barbers/<folder>, without touching any
 * other barber field (bio, imageUrl, videoUrl, salons, etc.) or any other table.
 *
 * Run from the backend folder:
 *   npx tsx scripts/refresh-barber-galleries.ts
 *
 * It reads DATABASE_URL from the local .env file (same convention as
 * update-julien-bio.ts), so point .env at whichever database you want to
 * update before running (local vs production).
 */

import 'dotenv/config';
import path from 'path';
import fs from 'fs';
import { PrismaClient } from '@prisma/client';

const prisma = new PrismaClient();

const BARBERS = [
  { firstName: 'Tom', lastName: 'Martin', folder: 'Coupes TOM' },
  { firstName: 'Nathan', lastName: 'Dupont', folder: 'Coupe Nathan' },
  { firstName: 'Clément', lastName: 'Leroi', folder: 'coupes-clement' },
  { firstName: 'Louay', lastName: '', folder: 'Coupe Louay' },
  { firstName: 'Lucas', lastName: 'Bernard', folder: 'Coupe Lucas' },
  { firstName: 'Julien', lastName: 'Morel', folder: 'Coupe Ju' },
  { firstName: 'Alan', lastName: 'Smith', folder: 'Coupe Alan' },
];

const VALID_IMAGE_EXTS = ['.jpg', '.jpeg', '.png', '.avif', '.webp'];

function getBarberGallery(folderName: string): string[] {
  const dirPath = path.join(process.cwd(), 'public/images/barbers', folderName);
  if (!fs.existsSync(dirPath)) {
    console.warn(`Warning: folder not found at ${dirPath}`);
    return [];
  }
  const files = fs.readdirSync(dirPath).filter((file) => {
    if (file.startsWith('.')) return false;
    return VALID_IMAGE_EXTS.includes(path.extname(file).toLowerCase());
  });
  return files.map((file) => `/images/barbers/${folderName}/${file}`);
}

async function main() {
  for (const b of BARBERS) {
    const existing = await prisma.barber.findFirst({
      where: { firstName: b.firstName, lastName: b.lastName },
      select: { id: true, imageUrl: true, images: true, gallery: true },
    });
    if (!existing) {
      console.warn(`SKIP: no barber found for ${b.firstName} ${b.lastName}`);
      continue;
    }
    const profileUrl = existing.imageUrl ?? existing.images[0] ?? null;
    const folderImages = getBarberGallery(b.folder);
    const newGallery = profileUrl ? [profileUrl, ...folderImages] : folderImages;

    const before = existing.gallery;
    const unchanged =
      before.length === newGallery.length && before.every((url, i) => url === newGallery[i]);

    if (unchanged) {
      console.log(`= ${b.firstName}: gallery already up to date (${before.length} items)`);
      continue;
    }

    await prisma.barber.update({
      where: { id: existing.id },
      data: { gallery: newGallery },
    });
    console.log(`~ ${b.firstName}: gallery ${before.length} -> ${newGallery.length} items`);
  }
}

main()
  .catch((error) => {
    console.error(error);
    process.exitCode = 1;
  })
  .finally(async () => {
    await prisma.$disconnect();
  });
