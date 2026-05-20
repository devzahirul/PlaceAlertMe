# GitHub Actions Workflows

Complete CI/CD setup for PlaceAlertMe with automated testing, coverage, and deployment.

## Overview

PlaceAlertMe uses GitHub Actions to automatically:
- ✅ Run 60+ tests across C++, Android, and iOS
- ✅ Generate code coverage reports
- ✅ Perform code quality checks
- ✅ Run security scans
- ✅ Build release artifacts
- ✅ Comment results on PRs

## Workflows

### 1. Tests Workflow (`tests.yml`)

**Trigger:** Push to main/develop/claude/*, Pull requests

**Jobs:**
- **cpp-tests** - C++ Google Test suite
- **android-unit-tests** - JUnit tests
- **android-instrumented-tests** - Android emulator tests
- **ios-tests** - XCTest suite
- **code-coverage** - Coverage report aggregation
- **test-summary** - Summary with PR comment

**Features:**
- 🧪 Runs all tests in parallel
- 📊 Publishes test results
- 💬 Comments on PRs
- ⏱️ ~5-10 minutes execution time

**Status Badge:**
```markdown
![Tests](https://github.com/devzahirul/PlaceAlertMe/workflows/Tests/badge.svg)
```

### 2. Coverage Workflow (`coverage.yml`)

**Trigger:** Push to main/develop, Pull requests

**Jobs:**
- **android-coverage** - Jacoco coverage report
- **ios-coverage** - Xcode coverage extraction
- **coverage-badge** - Updates coverage badge

**Features:**
- 📈 Generates coverage reports
- 🏷️ Updates coverage badges
- 📤 Uploads to Codecov

**Environment:**
```
Android: Ubuntu
iOS: macOS
```

### 3. Build Workflow (`build.yml`)

**Trigger:** Push, Pull requests, Tags

**Jobs:**
- **cpp-build** - C++ library compilation
- **android-build** - AAR library generation
- **ios-build** - Framework and SPM build
- **matrix-build** - Multi-platform builds

**Features:**
- 🏗️ Builds all libraries
- 📦 Generates artifacts
- 🔄 Supports matrix builds
- 🚀 Creates releases on tags

**Platforms:**
- Linux (C++ static lib)
- macOS (C++ + iOS)
- Windows (C++ with MSVC)

### 4. Code Quality Workflow (`lint-code-quality.yml`)

**Trigger:** Push, Pull requests

**Jobs:**
- **kotlin-lint** - ktlint for Android
- **swift-lint** - SwiftLint for iOS
- **cpp-analysis** - cppcheck & clang-tidy
- **security-scan** - Trivy vulnerability scanner
- **codeql-analysis** - CodeQL security analysis

**Features:**
- 📝 Lint checking
- 🔍 Static analysis
- 🔐 Security scanning
- 📊 SARIF reports

## Workflow Files

```
.github/workflows/
├── tests.yml                  # 60+ unit tests
├── coverage.yml               # Code coverage
├── build.yml                  # Build artifacts
├── lint-code-quality.yml      # Code quality
└── WORKFLOWS.md              # This file
```

## CI/CD Pipeline

```
┌─────────────┐
│  Push/PR    │
└──────┬──────┘
       │
       ├─────────────────┬──────────────────┬──────────────┐
       │                 │                  │              │
       ▼                 ▼                  ▼              ▼
  ┌─────────┐      ┌──────────┐      ┌──────────┐   ┌──────────┐
  │  Tests  │      │  Build   │      │ Coverage │   │  Quality │
  └────┬────┘      └─────┬────┘      └────┬─────┘   └────┬─────┘
       │                 │                │             │
       │  5-10 min       │ 10-15 min      │ 5-10 min   │ 5 min
       │                 │                │             │
       └─────────────────┴────────────────┴─────────────┘
                        │
                        ▼
            ┌────────────────────────┐
            │  Summary & PR Comment  │
            └────────────────────────┘
```

## Usage Examples

### View Workflow Status
```bash
# List all workflow runs
gh run list

# View specific workflow
gh run list --workflow=tests.yml

# View specific run
gh run view <run-id>
```

### View Test Results
```bash
# Download test artifacts
gh run download <run-id> -n cpp-test-results

# View test summary
gh run view <run-id> --log
```

### Trigger Workflow Manually
```bash
# Trigger tests workflow
gh workflow run tests.yml

# Trigger build workflow
gh workflow run build.yml
```

## Environment Setup

### Secrets (Optional)

Add to `.github/secrets/`:
- `CODECOV_TOKEN` - For Codecov integration
- `GITHUB_TOKEN` - Auto-provided by GitHub

### Actions Used

- `actions/checkout@v3` - Clone repository
- `actions/setup-java@v3` - Java environment
- `actions/setup-xcode@v1` - Xcode setup
- `android-actions/setup-android@v2` - Android SDK
- `reactivecircus/android-emulator-runner@v2` - Android emulator
- `codecov/codecov-action@v3` - Coverage upload
- `EnricoMi/publish-unit-test-result-action@v2` - Test publishing
- `actions/upload-artifact@v3` - Artifact storage
- `github/codeql-action/*` - CodeQL analysis

## Test Results

### Test Reports Location

**C++:**
```
cpp/geo_engine/tests/build/test-results.xml
```

**Android:**
```
android/geo-engine/build/test-results/
android/geo-engine/build/reports/jacoco/
```

**iOS:**
```
ios/test-results.xcresult/
ios/coverage.json
```

### Coverage Reports

**Android:**
```
android/geo-engine/build/reports/jacoco/jacocoTestReport/html/
```

**Overall:**
```
.github/badges/coverage.json
```

## Troubleshooting

### Tests Failing on CI

**Check logs:**
```bash
gh run view <run-id> --log
```

**Common issues:**
- Missing Android SDK
- Emulator not available
- Xcode version incompatible
- Missing dependencies

### Build Artifacts Not Generated

**Verify build succeeded:**
```bash
gh run view <run-id> --log | grep -A 5 "Build"
```

**Download artifacts:**
```bash
gh run download <run-id> -n <artifact-name>
```

### Coverage Not Updated

**Check coverage workflow:**
```bash
gh run list --workflow=coverage.yml
```

**Manual update:**
```bash
# Trigger coverage workflow
gh workflow run coverage.yml
```

## Performance

### Execution Times

| Workflow | Time | Notes |
|----------|------|-------|
| Tests | 5-10 min | Parallel execution |
| Build | 10-15 min | Multi-platform |
| Coverage | 5-10 min | Depends on tests |
| Quality | 5 min | Static analysis |
| **Total** | **20-30 min** | Full pipeline |

### Optimization Tips

1. **Cache dependencies:**
   ```yaml
   - uses: actions/cache@v3
     with:
       path: ~/.gradle/caches
       key: gradle-${{ hashFiles('**/gradle-wrapper.properties') }}
   ```

2. **Parallel jobs:**
   ```yaml
   jobs:
     job1:
       runs-on: ubuntu-latest
     job2:
       runs-on: ubuntu-latest
   ```

3. **Skip slow jobs conditionally:**
   ```yaml
   if: github.event_name == 'pull_request' && !contains(github.head_ref, 'docs/')
   ```

## Status Badges

Add to `README.md`:

```markdown
# PlaceAlertMe

[![Tests](https://github.com/devzahirul/PlaceAlertMe/workflows/Tests/badge.svg)](https://github.com/devzahirul/PlaceAlertMe/actions/workflows/tests.yml)
[![Build](https://github.com/devzahirul/PlaceAlertMe/workflows/Build/badge.svg)](https://github.com/devzahirul/PlaceAlertMe/actions/workflows/build.yml)
[![Code Quality](https://github.com/devzahirul/PlaceAlertMe/workflows/Code%20Quality/badge.svg)](https://github.com/devzahirul/PlaceAlertMe/actions/workflows/lint-code-quality.yml)
```

## Next Steps

1. **Enable branch protection** - Require status checks
2. **Configure auto-deployment** - Deploy on tags
3. **Setup Slack notifications** - Get alerts
4. **Add pre-commit hooks** - Local validation

## Maintenance

### Update Dependencies

Periodically update action versions:
```bash
git pull
git checkout -b update-actions
# Update version numbers in .github/workflows/
git push origin update-actions
# Create PR to review changes
```

### Monitor Workflows

**Weekly check:**
```bash
gh run list --workflow=tests.yml --created=<7 days ago>
```

**Failure analysis:**
```bash
gh run list --status failure --limit 10
```

## Support

- 📚 [GitHub Actions Documentation](https://docs.github.com/en/actions)
- 🔍 [Workflow Status](https://github.com/devzahirul/PlaceAlertMe/actions)
- 📖 [TESTING.md](../../TESTING.md) - Testing guide
- 🚀 [BUILD.md](../../BUILD.md) - Build instructions

---

**Last Updated:** 2024-05-20  
**Status:** ✅ Production Ready
