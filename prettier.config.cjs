module.exports = {
  // eslint-disable-next-line @typescript-eslint/no-require-imports
  ...require('@offchainlabs/prettier-config'),
  // override here
  plugins: ['@trivago/prettier-plugin-sort-imports'],
  importOrder: [
    '^node:',
    '^react$',
    '^react/',
    '<THIRD_PARTY_MODULES>',
    '^@/(.*)$',
    '^\\.\\./',
    '^\\./',
  ],
  importOrderSeparation: true,
  importOrderSortSpecifiers: true,
};
