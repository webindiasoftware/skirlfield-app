# SkirlField — field staff app (Flutter, Android + iOS)

First version: sign-in with phone binding, start / pause / end duty, background GPS with an offline queue,
today's distance and time, my attendance month with correction requests, phone-setup checklist, profile.
Visits and Expenses tabs are placeholders for later sprints. Build steps: **INSTALL.md**.

## How tracking works
| Piece | File | What it does |
|---|---|---|
| Location stream | `lib/tracking/tracker.dart` | Android: geolocator foreground service with an "On duty" notification (keeps running with the screen off). iOS: background location updates. |
| Phone-side filter | `Tracker._keep` | Drops fixes worse than `gps.max_accuracy_m`; keeps a point every `gps.min_move_m` metres, or every `gps.interval_stationary_s` when standing still. Fake-location points are always sent so the server can flag them. |
| Offline queue | `lib/tracking/point_queue.dart` | SQLite on the phone. Points are deleted only after the server accepts the batch (re-sending is safe: the server ignores duplicates). |
| Upload | `Tracker.flush` | Batches of up to 300, when `gps.batch_size` points are waiting or every `gps.batch_max_wait_s`; retries every minute when offline. |
| Heartbeat | `Tracker._heartbeat` | Every `gps.heartbeat_s`: battery, GPS on/off, permission, battery optimisation → the live map shows *No signal* / raises alerts. |
| Restart safety | `Tracker.resumeFromDisk` + `restore` | If the phone kills the app, tracking resumes the next time it opens; the server's view of today wins. |
| Ending without network | `DutyState.endDuty` | The end time is saved and sent automatically later (server accepts up to 24 h late). |

All the numbers above come from the company's settings on the server (Settings → Rules in the web app), sent with
`/attendance/today` and `start-duty`.

## Code map
```
lib/
  main.dart                 app start, Root (login / change password / shell)
  config.dart               API base URL (override with --dart-define=API_BASE=...)
  theme.dart                Stitch colours
  models.dart               API models
  core/api.dart             Dio client, token refresh, ApiException
  core/storage.dart         tokens + phone id in Keystore / Keychain
  core/device.dart          phone details sent at login
  core/format.dart          time / km formatting
  state/auth_state.dart     sign in, profile, change password, sign out
  state/duty_state.dart     today, start / pause / resume / end duty
  tracking/                 tracker, queue, permissions
  screens/                  login, home, start duty, attendance, corrections, profile, permissions, coming soon
platform/                   manifest snippets that setup.ps1 / setup.sh merge into the generated android/ project
```

## Notes
* **One phone per employee.** The first sign-in binds the phone. Reinstalling the app or a new phone needs HR approval
  in the web app (Approval Centre → Phone changes), unless the company setting is "replace automatically".
* Only field employees with tracking on can start duty; others see an explanation on Home.
* Xiaomi / Oppo / Vivo / Realme kill background apps aggressively: the Phone setup screen tells staff to allow
  Autostart and "No restrictions" battery.
