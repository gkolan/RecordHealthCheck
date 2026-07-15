const { jestConfig } = require("@salesforce/sfdx-lwc-jest/config");

module.exports = {
  ...jestConfig,
  modulePathIgnorePatterns: ["<rootDir>/.localdevserver"],
  // Keep the source glob at the bundle level. The sfdx-lwc-jest resolver does
  // not instrument this project through the recursive `lwc/**/*` pattern and
  // silently reports an empty 0% table, which bypasses coverage thresholds.
  collectCoverageFrom: ["force-app/main/default/lwc/recordHealthCheck/*.js"],
  coverageThreshold: {
    global: {
      branches: 75,
      functions: 90,
      lines: 85,
      statements: 85
    }
  }
};
