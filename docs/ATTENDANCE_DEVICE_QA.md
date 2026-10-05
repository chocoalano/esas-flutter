# Attendance — physical device QA worksheet

Liveness cannot be judged on a simulator and cannot be judged from a golden. ML
Kit needs a real camera, and the two things most likely to be wrong — the
geometry of the front camera and the size of a face at arm's length — are
invisible from anywhere else.

**Nothing in this worksheet records a face.** No screenshots of the camera, no
captured stills, no match scores in the repository. Write down codes, timings
and pass/fail; if a capture has to be looked at, it stays in the HR panel where
it already lives under access control.

---

## 0. Before you start

| | |
|---|---|
| Environment | **development or staging.** Never production — see §5 of the pass brief. |
| Tenant | a dedicated **test tenant** |
| Employee | a dedicated **test employee**, never a colleague's real enrolment |
| Face enrolment | enrolled by HR in the panel **with consent recorded** — `UserFaceReference::isUsable()` requires `consent_recorded_at`, and it must not be bypassed to make QA easier |
| Backend build | record it if the deployment exposes one; today it does **not** (see the report's §I) — note the deploy time or commit from whoever deployed it |

```
Device:            ______________________  (e.g. iPhone 14, Galaxy A54)
OS:                ______________________
App build:         ______________________  (version+build from the About screen)
Front camera:      ______________________  (megapixels if known)
Backend env:       ______________________
Backend build:     ______________________  (or "unknown — no version endpoint")
Tester / date:     ______________________
```

The debug build shows a diagnostics strip at the bottom-left of the liveness
viewport while a capture runs:

```
scored=41 dropped=118 9.8/s detector=71ms faces=1 ratio=0.34 elapsed=4200ms
```

* `scored/dropped` — backpressure working looks like a healthy `scored` rate
  with a large `dropped` count. Both falling means the handset cannot keep up.
* `detector` — one ML Kit call. Above ~100 ms on a mid-range phone is worth
  noting.
* `ratio` — how much of the frame's shorter side the face fills. Compare against
  `minFaceSize: 0.2`; anything near or below it explains a face that will not
  register.

The strip is compiled out of release builds.

---

## 1. MIRRORING — DO THIS FIRST

The client corrects for iOS mirroring the streamed frames of the front camera
(Android does not). It is unit-pinned but **has never run on a real device**. If
it is wrong, every gesture threshold measured afterwards is measured against
reversed geometry.

> **If either row fails, stop. Fix the geometry before recording anything else
> in this worksheet.**

| Platform | Server asks | You turn to your own | Expect | Result |
|---|---|---|---|---|
| iPhone | `turn_left` | **left** | accepted | ☐ pass ☐ fail |
| iPhone | `turn_right` | **right** | accepted | ☐ pass ☐ fail |
| Android | `turn_left` | **left** | accepted | ☐ pass ☐ fail |
| Android | `turn_right` | **right** | accepted | ☐ pass ☐ fail |

A quick negative check, on each platform: asked for `turn_left`, turn to your
**right**. It must be refused.

| Platform | Wrong-way turn refused | Result |
|---|---|---|
| iPhone | | ☐ pass ☐ fail |
| Android | | ☐ pass ☐ fail |

---

## 2. Liveness — gestures

Only the six the server can draw. There is no mouth-open gesture: ML Kit reports
no mouth-open probability, which is why the catalogue offers `smile` instead.

| Gesture | Accepted | Time to accept | Notes |
|---|---|---|---|
| `turn_left` | ☐ | ____ s | |
| `turn_right` | ☐ | ____ s | |
| `look_up` | ☐ | ____ s | |
| `look_down` | ☐ | ____ s | |
| `blink` | ☐ | ____ s | |
| `smile` | ☐ | ____ s | |

---

## 3. Liveness — conditions

| Case | Expected | Result |
|---|---|---|
| Two faces in frame mid-sequence | not scored; hint asks for one face | ☐ |
| Face leaves frame > 1.5 s | attempt ends naming continuity, **not** "you did not move" | ☐ |
| Face leaves < 0.6 s (a turn losing detection) | sequence continues | ☐ |
| Glasses | eye axis may saturate → "wajah belum terbaca jelas" | ☐ |
| Resting smile at the camera | mouth saturates → one retake, then a refusal that says so | ☐ |
| Low light | refusal names lighting, not movement | ☐ |
| Back-lit (window behind) | as above | ☐ |
| Challenge left to expire mid-sequence | "Waktu verifikasi habis"; **no photograph taken** | ☐ |
| Background mid-challenge, then return | attempt abandoned, camera released, temp file gone | ☐ |
| Network lost after capture | "Status absensi belum pasti", **no retry offered** | ☐ |
| Server rejection (`face_no_match`) | retry starts a **new** challenge | ☐ |

Record for each capture:

| Attempt | Time to baseline | Capture latency | Submit latency | Server code | Result |
|---|---|---|---|---|---|
| 1 | ____ s | ____ ms | ____ ms | ____________ | ☐ pass ☐ fail |
| 2 | ____ s | ____ ms | ____ ms | ____________ | ☐ pass ☐ fail |
| 3 | ____ s | ____ ms | ____ ms | ____________ | ☐ pass ☐ fail |

---

## 4. Face size at arm's length

**Measurement only — no code changes this pass.** `ResolutionPreset.medium` and
`minFaceSize: 0.2` are frozen until this table exists.

| Holding distance | `ratio` from the strip | Detected | Notes |
|---|---|---|---|
| Comfortable (~30 cm) | ____ | ☐ | |
| Extended arm (~50 cm) | ____ | ☐ | |
| Close (~20 cm) | ____ | ☐ | |

Also note the observed match outcome at each distance if the HR panel exposes
one. **Do not display any score in the app.**

---

## 5. QR

| Case | Expected | Result |
|---|---|---|
| Valid department QR | clock recorded, receipt shows the **server's** time | ☐ |
| Valid machine QR | as above; direction comes from `next_presence` | ☐ |
| Expired department QR | `qr_expired`, scanner keeps running | ☐ |
| Expired machine QR | `code_expired`, scanner keeps running | ☐ |
| Wrong tenant | refused before leaving the handset | ☐ |
| Tampered JSON / random QR | "bukan QR absensi", scanner keeps running | ☐ |
| Invalid HMAC (edited machine code) | `invalid_code` from the server | ☐ |
| Same code scanned twice | second is `code_already_used` / `qr_already_used` | ☐ |
| Same code after a successful clock | as above — **not** a second clock | ☐ |
| Stale `next_presence` (clock in on another device first) | server refuses `already_clocked_in` | ☐ |
| Outside the geofence | refused before the code is spent | ☐ |
| Location unavailable | `location_required` from the server, or a location block | ☐ |
| Network timeout after submit | "Status absensi belum pasti", no retry offered | ☐ |
| Phone clock set 10 min fast, valid code | **still clocks** — expiry is the server's call | ☐ |

---

## 6. Idempotency (needs a proxy or airplane-mode trick)

The point is a *lost reply*, not a double tap.

| Case | Expected | Result |
|---|---|---|
| Kill the network right after submit, then retry the same attempt | one attendance row, one receipt | ☐ |
| Check the header on the replay | `Idempotency-Status: replayed` | ☐ |
| Two rapid scans of two different codes | two separate attempts, second meets `already_clocked_in` | ☐ |

---

## 7. Camera lifecycle

| Case | Expected | Result |
|---|---|---|
| QR → Face → QR | one camera open at a time; no black preview | ☐ |
| Absensi → Beranda → Absensi | camera released and reopened cleanly | ☐ |
| Background / resume | preview recovers; location re-read where a fence applies | ☐ |
| Lock / unlock | as above | ☐ |
| Deny camera → Settings → allow | "Buka pengaturan" leads, then the camera starts | ☐ |
| Another app holding the camera | failure named, "Coba lagi" recovers | ☐ |
| After every liveness attempt | **no image left in the app cache** | ☐ |

---

## 8. Capability wiring

| Server says | Expect | Result |
|---|---|---|
| `qr_enabled: true`, `face_enrolled: true` | both segments selectable | ☐ |
| `qr_enabled: false`, `face_enrolled: true` | QR locked with its own note; face usable | ☐ |
| `qr_enabled: true`, `face_enrolled: false` | face locked, "belum didaftarkan HR" | ☐ |
| field absent (older backend) | QR attemptable, server still authority | ☐ |
| `attendance_enabled: false` | both locked, "Hubungi HR" | ☐ |
