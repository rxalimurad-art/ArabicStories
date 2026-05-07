const {getDefaultConfig, mergeConfig} = require('@react-native/metro-config');

/**
 * Metro configuration
 * https://facebook.github.io/metro/docs/configuration
 *
 * @type {import('metro-config').MetroConfig}
 */
const config = {
  watchFolders: [],
  resolver: {
    blockList: [
      /node_modules\/.*\/package\.json$/,
      /node_modules\/.*\/tsconfig\.json$/,
      /\.git\/.*/,
      /ios\/build\/.*/,
      /android\/app\/build\/.*/,
    ],
  },
  watcher: {
    watchman: {
      deferStates: ['hg.update'],
    },
    healthCheck: {
      enabled: true,
    },
  },
};

module.exports = mergeConfig(getDefaultConfig(__dirname), config);