const path = require('node:path');
const { getDefaultConfig, mergeConfig } = require('@react-native/metro-config');

// @shomer/app is NOT an npm-workspace member (react-native / Metro
// dislike dependency hoisting), so Metro is told explicitly where the
// shared @shomer/lib sources live: watchFolders lets it serve files
// from outside the app root, extraNodeModules resolves the bare import.
const libRoot = path.resolve(__dirname, '..', 'lib');

/**
 * Metro configuration
 * https://reactnative.dev/docs/metro
 *
 * @type {import('@react-native/metro-config').MetroConfig}
 */
const config = {
  watchFolders: [libRoot],
  resolver: {
    extraNodeModules: {
      '@shomer/lib': libRoot,
    },
    nodeModulesPaths: [path.resolve(__dirname, 'node_modules')],
  },
};

module.exports = mergeConfig(getDefaultConfig(__dirname), config);
