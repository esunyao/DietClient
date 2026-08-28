module.exports = {
  root: true,
  extends: '@react-native',
  overrides: [
    {
      files: ['src/features/auth/**/*.{ts,tsx}'],
      rules: {
        'no-restricted-imports': [
          'error',
          { patterns: ['**/features/diet/**', '**/features/profile/**'] },
        ],
      },
    },
    {
      files: ['src/features/diet/**/*.{ts,tsx}'],
      rules: {
        'no-restricted-imports': [
          'error',
          { patterns: ['**/features/auth/**', '**/features/profile/**'] },
        ],
      },
    },
    {
      files: ['src/features/profile/**/*.{ts,tsx}'],
      rules: {
        'no-restricted-imports': [
          'error',
          { patterns: ['**/features/auth/**', '**/features/diet/**'] },
        ],
      },
    },
    {
      files: ['src/shared/**/*.{ts,tsx}'],
      rules: {
        'no-restricted-imports': [
          'error',
          { patterns: ['**/features/**', '**/app/**', '**/navigation/**'] },
        ],
      },
    },
  ],
};
