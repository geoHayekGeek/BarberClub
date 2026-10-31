// These tests mock every database client. Integration tests keep their separate
// TEST_DATABASE_URL safety guard in jest.config.js.
module.exports = {
  preset: 'ts-jest',
  testEnvironment: 'node',
  roots: ['<rootDir>/tests/unit'],
  testMatch: ['**/*.unit.test.ts'],
  maxWorkers: 1,
  clearMocks: true,
};
