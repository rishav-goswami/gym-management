module.exports = {
  preset: "ts-jest",
  testEnvironment: "node",
  clearMocks: true,
  collectCoverageFrom: ["src/**/*.ts", "!src/index.ts", "!src/models/index.ts"],
};
