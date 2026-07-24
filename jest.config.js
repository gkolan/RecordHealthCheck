const { jestConfig } = require("@salesforce/sfdx-lwc-jest/config");

module.exports = {
  ...jestConfig,
  modulePathIgnorePatterns: ["<rootDir>/.localdevserver"],
  // List production modules explicitly. sfdx-lwc-jest silently produced an
  // empty 0% report for bundle-level globs, which also bypassed thresholds.
  collectCoverageFrom: [
    "force-app/main/default/lwc/recordHealthCheck/recordHealthCheck.js",
    "force-app/main/default/lwc/recordHealthCheck/healthCheckModel.js",
    "force-app/main/default/lwc/recordHealthCheck/healthCheckPresentation.js",
    "force-app/main/default/lwc/recordHealthCheck/healthCheckRunner.js"
  ],
  coverageThreshold: {
    global: {
      branches: 75,
      functions: 96,
      lines: 96,
      statements: 85
    }
  }
};
