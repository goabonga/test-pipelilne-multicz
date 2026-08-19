module.exports = {
  preset: '@react-native/jest-preset',
  // Resolve the shared package straight to its TS source. The path is
  // outside node_modules, so babel-jest (RN preset) transpiles it — no
  // transformIgnorePatterns juggling, and the app tests the very same
  // code the bundle ships.
  moduleNameMapper: {
    '^@shomer/lib$': '<rootDir>/../lib/src/index.ts',

    // AND THE CONSEQUENCE OF THAT MAPPING, which only shows up in CI.
    //
    // Transpiling lib's sources means Babel's transform-runtime rewrites
    // its helpers into `require('@babel/runtime/helpers/...')`. Jest
    // resolves that require relative to the file being transformed — a
    // file in packages/lib/src — so it looks in packages/lib/node_modules
    // and then the repository root, never in this package, which is the
    // only place @babel/runtime is declared.
    //
    // Locally it resolved by accident: the root node_modules carried a
    // hoisted copy. CI installs packages/app alone, so there is no root
    // tree and the suite failed on a missing module in a file nobody had
    // touched. Reproduced here by moving the root copy aside.
    //
    // Mapping it explicitly makes the resolution independent of where the
    // source file happens to live, which is the same reason @shomer/lib
    // is mapped above.
    '^@babel/runtime/(.*)$': '<rootDir>/node_modules/@babel/runtime/$1',
  },
};
