const { jestConfig } = require("@salesforce/sfdx-lwc-jest/config");

module.exports = {
  ...jestConfig,
  modulePathIgnorePatterns: ["<rootDir>/.localdevserver"],
  // Keep the source glob at the bundle level. The sfdx-lwc-jest resolver does
  // not instrument this project through the recursive `lwc/**/*` pattern and
  // silently reports an empty 0% table, which bypasses coverage thresholds.
  // Jest's LWC transformer only discovers source files through a bare `*`
  // pattern. A `*.js` glob produces an empty report and silently bypasses the
  // threshold, even though the JavaScript files exist.
  collectCoverageFrom: [
    "force-app/main/default/lwc/recordHealthCheck/*",
    "!force-app/main/default/lwc/recordHealthCheck/*.html",
    "!force-app/main/default/lwc/recordHealthCheck/*.css"
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
