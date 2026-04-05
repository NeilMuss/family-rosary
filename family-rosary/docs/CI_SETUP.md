# TestFlight CI Setup

This repository uses one GitHub Actions workflow that runs the same local Fastlane lane:

- Workflow: `.github/workflows/ios-beta.yml`
- Lane: `bundle exec fastlane ios beta`

## Required GitHub Secrets

- `ASC_KEY_ID`
- `ASC_ISSUER_ID`
- `ASC_PRIVATE_KEY_BASE64`
- `MATCH_GIT_URL`
- `MATCH_PASSWORD`
- `MATCH_GIT_BASIC_AUTHORIZATION`

## Behavior

- A push to `main` triggers a TestFlight upload.
- Authentication uses App Store Connect API key only (no Apple ID login in CI).
- Signing uses `match` with the signing repository from secrets.
- Build number is auto-incremented by reading the current marketing version from Xcode, finding the latest TestFlight build for that version, and using the next integer.
- No secrets are committed to the repository.
