# runanalyze mobile

This repository contains a minimal Flutter mobile app scaffold implementing a basic dashboard inspired by https://runalyze.com/dashboard. It is an SDD-driven starting point to view weekly, monthly, and annual activity statistics on an Android Pixel 10 (or emulator).

See /sdd/SPEC.md for the SDD specification used to drive development.

## Wireless debugging (WSL)

### On the phone

1. Enable Developer options (Settings → About phone → tap Build number 7 times)
2. Turn on **Wireless debugging**
3. Tap **Wireless debugging** → **Pair device with pairing code**
4. Keep that screen open — note the IP address, pair port, and ADB port shown

### In WSL terminal

```bash
adb kill-server
adb start-server
adb pair <PHONE_IP>:<PAIR_PORT>   # enter pairing code when prompted
adb connect <PHONE_IP>:<ADB_PORT> # use the port shown on the main Wireless debugging screen
adb devices -l
flutter devices
flutter run -d <DEVICE_ID>
```

> **Note:** The pair port and connect port are different numbers. Use the pair port only for
> `adb pair`, then use the separate ADB port shown on the main Wireless debugging screen for
> `adb connect`.

---

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
