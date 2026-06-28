# runanalyze mobile

This repository contains a minimal Flutter mobile app scaffold implementing a basic dashboard inspired by https://runalyze.com/dashboard. It is an SDD-driven starting point to view weekly, monthly, and annual activity statistics on an Android Pixel 10 (or emulator).

See /sdd/SPEC.md for the SDD specification used to drive development.

## Debug startup (API probe mode)

You can launch directly into the API Probe screen for request/response diagnostics.

```bash
flutter run --dart-define=API_PROBE_MODE=true
```

In probe mode you can:

- Run a single API call for page 1 with configurable `itemsPerPage`
- Switch between latest payload and window-filtered analysis
- Dump full probe payload to Flutter console (request URL/headers, status, response headers/body, errors)

### Save probe logs to a file

```bash
mkdir -p logs
flutter run --dart-define=API_PROBE_MODE=true | tee logs/api_probe.log
```

Probe dumps are wrapped with markers for easy searching:

- `=== RUNANALYZE_API_PROBE_START ===`
- `=== RUNANALYZE_API_PROBE_END ===`
