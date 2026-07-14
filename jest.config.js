const { jestConfig } = require("@salesforce/sfdx-lwc-jest/config");

module.exports = {
  ...jestConfig,
  modulePathIgnorePatterns: ["<rootDir>/.localdevserver"],
  // Use a bare `*` (not `*.js`): the sfdx-lwc-jest resolver won't match source
  // files under a `**/*.js` glob, which silently reports 0% coverage. The
  // negations below drop the non-JS artifacts and the test files themselves.
  collectCoverageFrom: [
    "force-app/main/default/lwc/**/*",
    "!force-app/main/default/lwc/**/*.html",
    "!force-app/main/default/lwc/**/*.css",
    "!force-app/main/default/lwc/**/*.js-meta.xml",
    "!force-app/main/default/lwc/**/__tests__/**"
  ],
  coverageThreshold: {
    global: {
      branches: 75,
      functions: 90,
      lines: 85,
      statements: 85
    }
  }
};
