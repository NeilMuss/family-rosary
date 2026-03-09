# TestFlight CI Setup

This repo uses GitHub Actions + fastlane to build and upload to TestFlight.

## Required GitHub secrets

- `ASC_KEY_ID`
- `ASC_ISSUER_ID`
- `ASC_KEY_P8`
- `MATCH_PASSWORD`
- `MATCH_GIT_URL`
- `APP_IDENTIFIER`
- `XCODE_SCHEME`
- `XCODE_WORKSPACE` or `XCODE_PROJECT`

## Optional GitHub secrets

- `MATCH_GIT_BASIC_AUTHORIZATION`
- `MATCH_GIT_BRANCH` (default: `main`)
- `MATCH_READONLY` (default: `true`)

## Notes

- Authentication uses App Store Connect API key (no Apple ID login).
- Signing uses fastlane `match` with a separate private signing repo.
- CI workflow: `.github/workflows/testflight.yml`
- Fastlane lane: `beta`
