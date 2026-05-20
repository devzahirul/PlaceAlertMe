# GitHub Configuration

This directory contains GitHub-specific configuration for PlaceAlertMe.

## Contents

### Workflows (`workflows/`)

Automated CI/CD pipelines:

- **tests.yml** - Run 60+ unit tests across C++, Android, iOS
  - 🧪 Google Test, JUnit, XCTest
  - 📊 Code coverage reporting
  - 💬 PR comments with results

- **coverage.yml** - Generate and track code coverage
  - 📈 Jacoco (Android) & Xcode (iOS)
  - 🏷️ Coverage badges
  - 📤 Codecov integration

- **build.yml** - Build libraries and artifacts
  - 🏗️ C++, Android AAR, iOS Framework
  - 🔄 Multi-platform matrix builds
  - 🚀 Release artifact creation

- **lint-code-quality.yml** - Code quality checks
  - 📝 ktlint, SwiftLint, cppcheck
  - 🔐 Security scanning (Trivy, CodeQL)
  - 📊 SARIF reports

### Documentation

- **WORKFLOWS.md** - Complete CI/CD documentation
  - Workflow details and triggers
  - Environment setup
  - Troubleshooting guide
  - Performance optimization

## Quick Reference

### View Status
```bash
gh run list
gh run view <run-id>
```

### Download Artifacts
```bash
gh run download <run-id> -n <artifact-name>
```

### Trigger Workflow
```bash
gh workflow run tests.yml
```

## Status Badges

```markdown
![Tests](https://github.com/devzahirul/PlaceAlertMe/workflows/Tests/badge.svg)
![Build](https://github.com/devzahirul/PlaceAlertMe/workflows/Build/badge.svg)
![Code Quality](https://github.com/devzahirul/PlaceAlertMe/workflows/Code%20Quality/badge.svg)
```

## Test Coverage

- **C++:** 95%+ (25 tests)
- **Android:** 85%+ (15+ tests)
- **iOS:** 90%+ (20+ tests)
- **Overall:** 90%+ coverage

## Performance

Total CI/CD pipeline: **20-30 minutes**

| Component | Time |
|-----------|------|
| Tests | 5-10 min |
| Build | 10-15 min |
| Coverage | 5-10 min |
| Quality | 5 min |

## More Information

- See [WORKFLOWS.md](WORKFLOWS.md) for detailed documentation
- See [../TESTING.md](../TESTING.md) for test information
- See [../BUILD.md](../BUILD.md) for build instructions
