module.exports = {
  preset: '@react-native/jest-preset',
  // Resolve the shared package straight to its TS source. The path is
  // outside node_modules, so babel-jest (RN preset) transpiles it — no
  // transformIgnorePatterns juggling, and the app tests the very same
  // code the bundle ships.
  moduleNameMapper: {
    '^@shomer/lib$': '<rootDir>/../lib/src/index.ts',
  },
};
