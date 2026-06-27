# SDD specification for RunAnalyze mobile

This document captures the initial Software Design Description (SDD) for a small mobile app that mirrors the basic statistics dashboard from https://runalyze.com/dashboard.

Goals
- Provide weekly, monthly, and annual overviews of running/cycling activities.
- Display totals for distance, duration, elevation, and average pace.
- Show a simple chart of activity counts or distances per time unit.
- Work on Android (Pixel 10) as primary target device.

Scope (MVP)
- Local mock data store (JSON) with sample activities.
- Three timeframe views: Week (last 7 days), Month (last 30 days), Year (last 365 days).
- Summary cards: Total distance, Total duration, Elevation gain, Average pace.
- Simple bar chart showing distance per day/week/month.
- Activity list showing date, distance, duration.

Non-functional
- Offline-first: app works with local data (MVP uses embedded JSON).
- Responsive layout for phone screen sizes (Pixel 10 as baseline).

Data model
- Activity: id, date (ISO 8601), type (run/ride), distance_km (double), duration_seconds (int), elevation_gain_m (int)

Example acceptance criteria (for SDD-driven tasks)
- Given the app has 10 activities in the last 30 days, When user switches to "Month", Then total distance should equal the sum of distance_km for those activities.
- Given activities across a year, When user selects "Year", Then the annual total distance and average pace are displayed.

Next steps for Copilot-driven implementation
1. Create Flutter scaffold and wire up the SDD acceptance tests as unit/widget tests.
2. Implement import of real workout files (GPX/TCX) and local persistence (sqflite) after MVP.
