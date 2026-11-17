module.exports = {
  preset: "ts-jest",
  testEnvironment: "node",
  roots: ["<rootDir>/tests"],
  setupFiles: ["<rootDir>/tests/setupEnv.ts"],
  collectCoverage: true,
  coverageDirectory: "coverage",
  coverageReporters: ["json", "html", "text", "lcov"],
  collectCoverageFrom: [
    "src/**/*.{ts,js}",
    "!src/**/*.d.ts",
    "!src/server.ts"
  ]
};
