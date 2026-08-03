const { jestConfig } = require("@salesforce/sfdx-lwc-jest/config");

module.exports = {
  ...jestConfig,
  modulePathIgnorePatterns: ["<rootDir>/.localdevserver"],
  // List production modules explicitly. sfdx-lwc-jest silently produced an
  // empty 0% report for bundle-level globs, which also bypassed thresholds.
  collectCoverageFrom: [
    "force-app/main/default/lwc/recordHealthCheck/recordHealthCheck.js",
    "force-app/main/default/lwc/recordHealthCheck/healthCheckDiagnostics.js",
    "force-app/main/default/lwc/recordHealthCheck/healthCheckModel.js",
    "force-app/main/default/lwc/recordHealthCheck/healthCheckPresentation.js",
    "force-app/main/default/lwc/recordHealthCheck/healthCheckRunner.js"
  ],
  coverageThreshold: {
    global: {
      branches: 75,
      functions: 98,
      lines: 98,
      statements: 98
    },
    "force-app/main/default/lwc/recordHealthCheck/recordHealthCheck.js": {
      lines: 98
    },
    "force-app/main/default/lwc/recordHealthCheck/healthCheckDiagnostics.js": {
      lines: 98
    },
    "force-app/main/default/lwc/recordHealthCheck/healthCheckModel.js": {
      lines: 98
    },
    "force-app/main/default/lwc/recordHealthCheck/healthCheckPresentation.js": {
      lines: 98
    },
    "force-app/main/default/lwc/recordHealthCheck/healthCheckRunner.js": {
      lines: 98
    }
  }
};
