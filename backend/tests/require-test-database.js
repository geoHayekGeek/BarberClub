const path = require('path');
const dotenv = require('dotenv');

dotenv.config({ path: path.resolve(__dirname, '..', '.env') });

const testDatabaseUrl = process.env.TEST_DATABASE_URL?.trim();
const defaultDatabaseUrl = process.env.DATABASE_URL?.trim();

if (!testDatabaseUrl) {
  throw new Error(
    'Refusing to run database tests without TEST_DATABASE_URL. ' +
      'Create a dedicated test database and set TEST_DATABASE_URL explicitly.',
  );
}

if (defaultDatabaseUrl && testDatabaseUrl === defaultDatabaseUrl) {
  throw new Error(
    'Refusing to run database tests because TEST_DATABASE_URL matches DATABASE_URL.',
  );
}

let parsedUrl;
try {
  parsedUrl = new URL(testDatabaseUrl);
} catch {
  throw new Error('TEST_DATABASE_URL must be a valid PostgreSQL connection URL.');
}

if (!['postgres:', 'postgresql:'].includes(parsedUrl.protocol)) {
  throw new Error('TEST_DATABASE_URL must use the postgres or postgresql protocol.');
}

// Source modules create their own Prisma clients from DATABASE_URL.
process.env.DATABASE_URL = testDatabaseUrl;
process.env.NODE_ENV = 'test';
