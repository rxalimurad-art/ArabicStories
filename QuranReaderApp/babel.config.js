module.exports = {
  presets: ['module:metro-react-native-babel-preset'],
  plugins: [
    [
      'module-resolver',
      {
        root: ['./src'],
        alias: {
          '@': './src',
          '@components': './src/components',
          '@screens': './src/screens',
          '@types': './src/types',
          '@utils': './src/utils',
          '@data': './src/data',
        },
      },
    ],
  ],
};