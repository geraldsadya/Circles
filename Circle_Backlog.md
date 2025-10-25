# 🗂 Project: Circle (iOS MVP) - Jira/Linear Backlog

**Methodology:** 2-week sprints • Story points (SP): 1=sm, 2=sm-med, 3=med, 5=lg, 8=xl
**Target:** iOS 16.4+ • Xcode 15+ • SwiftUI + MVVM • Core Data + CloudKit (mirroring)
**Labels used:** `ios`, `coredata`, `cloudkit`, `auth`, `location`, `motion`, `healthkit`, `screentime-lite`, `camera`, `background`, `notifications`, `privacy`, `ble-foreground`, `ckshare`, `cksubscription`, `perf`, `qa`

---

## EPICS

* **E1. App Bootstrap & Core Data / CloudKit**
* **E2. Auth & Onboarding + Permissions**
* **E3. Location, Geofences & Hangout Engine**
* **E4. Challenges & Verification (Location/Motion)**
* **E5. Points, Leaderboard & Forfeits**
* **E6. Camera Proof (Live Only)**
* **E7. Background Tasks & Notifications**
* **E8. Screen Time Lite (Fallback)**
* **E9. CloudKit Sharing & Subscriptions**
* **E10. Settings • Privacy • Data Export/Delete**
* **E11. Wrapped (Weekly Stub)**
* **E12. Performance, Power, QA & TestFlight**

---

## Sprint Plan (2 weeks)

* **Sprint 1 (Weeks 1):** CIR-1…CIR-24
* **Sprint 2 (Week 2):** CIR-25…CIR-48

---

## Backlog: Stories & Tasks

### E1. App Bootstrap & Core Data / CloudKit

**CIR-1** – App Project Bootstrap

* **Type:** Task • **SP:** 2 • **Labels:** ios
* **Desc:** Create Xcode project, bundle IDs (Debug/Prod), targets, schemes, SwiftPM deps.
* **AC:**

  * Given I open the project, Then I can build & run on device iOS 16.4+.
  * And schemes `Circle-Debug` and `Circle-Release` exist.
* **Deps:** —

**CIR-2** – Core Data Model (entities + migrations)

* **Type:** Story • **SP:** 5 • **Labels:** coredata
* **Desc:** Implement Core Data entities: `User, Circle, Membership, Challenge, ChallengeResult, HangoutSession, HangoutParticipant, PointsLedger, LeaderboardSnapshot, Forfeit, WrappedStats, ConsentLog, Device, ChallengeTemplate`.
* **AC:**

  * Given I run unit tests, Then CRUD succeeds for each entity.
  * And lightweight migration enabled.
* **Deps:** CIR-1

**CIR-3** – CloudKit Mirroring via NSPersistentCloudKitContainer

* **Type:** Story • **SP:** 3 • **Labels:** cloudkit, coredata
* **AC:**

  * Given iCloud signed-in device, Then records mirror to Private & Shared DBs.
  * And `automaticallyMergesChangesFromParent = true`.
* **Deps:** CIR-2

**CIR-4** – Build Config & Capabilities

* **Type:** Task • **SP:** 2 • **Labels:** ios
* **AC:** iCloud(CloudKit), Background Modes (location/fetch/processing), HealthKit, Push, Sign in with Apple enabled. **No BLE background modes.**
* **Deps:** CIR-1

---

### E2. Auth & Onboarding + Permissions

**CIR-5** – Sign in with Apple

* **Type:** Story • **SP:** 2 • **Labels:** auth
* **AC:**

  * Given user signs in, Then hashed subject ID stored (salt in Secure Enclave).
  * Logout clears local store & CK references.
* **Deps:** CIR-3

**CIR-6** – Progressive Permissions Flow (When-In-Use → Always)

* **Type:** Story • **SP:** 3 • **Labels:** privacy, location
* **AC:**

  * Given first run, Then When-In-Use requested with rationale.
  * Given meaningful use shown, Then Always upgrade prompt with explainer.
  * If denied, degraded mode accessible.
* **Deps:** CIR-5

**CIR-7** – Permissions Manager + ConsentLog

* **Type:** Task • **SP:** 2 • **Labels:** privacy
* **AC:** ConsentLog writes entries per permission grant/deny.
* **Deps:** CIR-2

---

### E3. Location, Geofences & Hangout Engine

**CIR-8** – Location Service (SLC + deferred + accuracy escalation)

* **Type:** Story • **SP:** 5 • **Labels:** location, background
* **AC:**

  * Idle: `.hundredMeters`, SLC/deferred.
  * Candidate/Active: `.nearestTenMeters` @ 60–90 s.
* **Deps:** CIR-6

**CIR-9** – Geofence Manager (Place goals)

* **Type:** Story • **SP:** 3 • **Labels:** location
* **AC:** Can create geofence (default 75 m), dwell ≥20 min detected, 1 credit/3h.
* **Deps:** CIR-8

**CIR-10** – Hangout Engine v1 (state machine)

* **Type:** Story • **SP:** 5 • **Labels:** location
* **AC:**

  * Candidate when distance ≤15 m, accuracy ≤30 m, samples ≤2 min old.
  * Active after 60 s continuous; End if >25 m or stale ≥3 min; merge gaps ≤2 min.
  * Per-user durations saved into HangoutParticipant.
* **Deps:** CIR-8, CIR-2

**CIR-11** – Anti-Cheat Heuristics (loc/motion sanity, uptime)

* **Type:** Story • **SP:** 3 • **Labels:** privacy, location, motion
* **AC:** If motion==running & GPS stationary >10 min → trigger camera prompt; durations validated using system uptime deltas.
* **Deps:** CIR-10, CIR-16

---

### E4. Challenges & Verification (Location/Motion)

**CIR-12** – Challenge Templates & Composer

* **Type:** Story • **SP:** 3 • **Labels:** challenges
* **AC:** Create from presets (Gym, Run, Sleep, Screen Lite, Custom) with params JSON.
* **Deps:** CIR-2

**CIR-13** – Challenge Engine & Scheduling

* **Type:** Story • **SP:** 3 • **Labels:** challenges, background
* **AC:** Daily/weekly windows computed; evaluation hooks exposed.
* **Deps:** CIR-12

**CIR-14** – Location Challenge Verification

* **Type:** Story • **SP:** 3 • **Labels:** location, challenges
* **AC:** Dwell ≥20 min inside geofence with accuracy ≤50 m for ≥80% of window → pass; 1 credit/3h.
* **Deps:** CIR-9, CIR-13

**CIR-15** – Motion Challenge Verification (steps/distance)

* **Type:** Story • **SP:** 3 • **Labels:** motion, challenges
* **AC:** CMPedometer aggregates steps/distance; time windows (e.g., before 8AM) respected.
* **Deps:** CIR-13

**CIR-16** – Motion Activity Classifier

* **Type:** Task • **SP:** 2 • **Labels:** motion
* **AC:** Walking/Running detection via CMMotionActivityManager; stored samples for sanity checks.
* **Deps:** CIR-15

---

### E5. Points, Leaderboard & Forfeits

**CIR-17** – Points Ledger & Totals

* **Type:** Story • **SP:** 3 • **Labels:** challenges
* **AC:** Challenge pass +10, fail −5, group pass +15, hangout +5/5min (cap +60/day), forfeit +5/−10.
* **Deps:** CIR-14, CIR-15, CIR-10

**CIR-18** – Weekly Leaderboard Snapshot

* **Type:** Story • **SP:** 3 • **Labels:** leaderboard
* **AC:** Snapshot job at Sun 23:55; deterministic ranks; top-3 crowns.
* **Deps:** CIR-17, CIR-31

**CIR-19** – Forfeit Engine

* **Type:** Story • **SP:** 3 • **Labels:** forfeits, camera
* **AC:** Bottom users assigned forfeit; completion gives +5, miss −10.
* **Deps:** CIR-18, CIR-22

---

### E6. Camera Proof (Live Only)

**CIR-20** – Camera Proof Service (AVFoundation)

* **Type:** Story • **SP:** 5 • **Labels:** camera, privacy
* **AC:** Live capture (2–3s clip or burst), random liveness prompts ("blink/turn/pan"), SHA-256 hash stored, media deleted immediately.
* **Deps:** CIR-5

**CIR-21** – Proof UI (modal + prompts + haptics)

* **Type:** Task • **SP:** 2 • **Labels:** camera, ios
* **AC:** Modal UX with instruction → capture → verify → success/fail states with haptics.
* **Deps:** CIR-20

**CIR-22** – Proof Hooks in Challenge/Hangout/Anti-Cheat

* **Type:** Task • **SP:** 2 • **Labels:** camera, challenges
* **AC:** Engine can trigger proof check; result updates `ChallengeResult` or `HangoutSession` notes.
* **Deps:** CIR-20, CIR-13, CIR-11

---

### E7. Background Tasks & Notifications

**CIR-23** – BGProcessing Rollups

* **Type:** Story • **SP:** 2 • **Labels:** background
* **AC:** Weekly leaderboard, data compaction; respects Low Power Mode.
* **Deps:** CIR-18

**CIR-24** – Local Notifications (reminders, forfeits)

* **Type:** Story • **SP:** 2 • **Labels:** notifications
* **AC:** Challenge window reminders; forfeit deadlines; tappable deep links.
* **Deps:** CIR-13, CIR-19

**CIR-25** – Push via CKSubscriptions

* **Type:** Story • **SP:** 3 • **Labels:** cloudkit, cksubscription, notifications
* **AC:** Subscriptions for Challenge, Result, Hangout, Forfeit; devices receive pushes on changes.
* **Deps:** CIR-3, CIR-9, CIR-13, CIR-10, CIR-19

---

### E8. Screen Time Lite (Fallback)

**CIR-26** – Focus Sessions + Random Proofs

* **Type:** Story • **SP:** 3 • **Labels:** screentime-lite, camera
* **AC:** User sets 2× blocks/day; random camera prompts; passing both → day pass.
* **Deps:** CIR-20, CIR-13

**CIR-27** – Strict DeviceActivity (feature flag)

* **Type:** Task • **SP:** 2 • **Labels:** screentime-lite
* **AC:** Capability check; shows toggle in Settings if entitlement present; otherwise hidden.
* **Deps:** CIR-26

---

### E9. CloudKit Sharing & Subscriptions

**CIR-28** – Circle Share (CKShare create/accept)

* **Type:** Story • **SP:** 3 • **Labels:** ckshare, cloudkit
* **AC:** Owner creates share; iMessage link; invitee accepts → Membership created; roles supported.
* **Deps:** CIR-3, CIR-5

**CIR-29** – Real-time Updates UI

* **Type:** Task • **SP:** 2 • **Labels:** cloudkit, ios
* **AC:** UI reacts to CK change notifications (new challenge/result/hangout/forfeit) without manual refresh.
* **Deps:** CIR-25

---

### E10. Settings • Privacy • Data Export/Delete

**CIR-30** – Privacy Page & Data Controls

* **Type:** Story • **SP:** 3 • **Labels:** privacy
* **AC:** Show what's collected (booleans/aggregates), Delete All Data, Export (JSON), Precise Location toggle per circle.
* **Deps:** CIR-2, CIR-3

**CIR-31** – Low Power / Cellular Throttling

* **Type:** Task • **SP:** 2 • **Labels:** perf
* **AC:** Sampling rates halved on Low Power; uploads throttled on cellular.
* **Deps:** CIR-8

---

### E11. Wrapped (Weekly Stub)

**CIR-32** – Weekly Summary Cards (stub)

* **Type:** Story • **SP:** 3 • **Labels:** ios
* **AC:** Aggregate week: time with friends, top location, challenges done; render 3 shareable cards.
* **Deps:** CIR-17, CIR-10

---

### E12. Performance, Power, QA & TestFlight

**CIR-33** – Urban/Indoor Accuracy Tests

* **Type:** QA • **SP:** 2 • **Labels:** qa, location
* **AC:** Pass criteria for downtown, mall, suburb; false positives <5%.
* **Deps:** CIR-10

**CIR-34** – Permission Denial Paths

* **Type:** QA • **SP:** 1 • **Labels:** qa, privacy
* **AC:** Degraded modes usable; no crash loops or hard blocks.
* **Deps:** CIR-6

**CIR-35** – Battery Impact Baseline

* **Type:** QA • **SP:** 2 • **Labels:** perf
* **AC:** 24h run < 3–5% overhead vs idle baseline, typical usage.
* **Deps:** CIR-8, CIR-31

**CIR-36** – App Privacy Nutrition Labels

* **Type:** Task • **SP:** 1 • **Labels:** privacy
* **AC:** App Store privacy answers reflect on-device verification; no media uploads.
* **Deps:** CIR-30

**CIR-37** – TestFlight Internal (build, notes, screenshots)

* **Type:** Task • **SP:** 2 • **Labels:** ios
* **AC:** Build distributed to internal testers; includes permissions explainer & review notes re: Screen Time fallback.
* **Deps:** All MVP core (CIR-1..CIR-32)

**CIR-38** – Crash & Log Baseline (OSLog)

* **Type:** Task • **SP:** 1 • **Labels:** ios
* **AC:** OSLog categories for services; no PII; symbolicated crash capture.
* **Deps:** CIR-1

**CIR-39** – App Icons & Theming (basic)

* **Type:** Task • **SP:** 1 • **Labels:** ios
* **AC:** App icons, accent colors, dark mode pass.
* **Deps:** —

**CIR-40** – Haptics & Micro-animations

* **Type:** Task • **SP:** 1 • **Labels:** ios
* **AC:** Success/fail haptics; subtle transitions on proof and leaderboard.
* **Deps:** CIR-21, CIR-18

---

## Optional / Phase-2 Tickets (parked but written)

**CIR-41** – BLE Foreground Proximity Refinement

* **Type:** Story • **SP:** 3 • **Labels:** ble-foreground
* **AC:** When app active on both devices, BLE RSSI > −70 dBm corroborates <10 m.
* **Deps:** CIR-10

**CIR-42** – Nearby Interaction (UWB) Exploration

* **Type:** Spike • **SP:** 3 • **Labels:** perf
* **AC:** Prototype U1-based distance in foreground; document device constraints.
* **Deps:** CIR-41

**CIR-43** – HealthKit Sleep Verification Flow

* **Type:** Story • **SP:** 3 • **Labels:** healthkit
* **AC:** Sleep before 23:00 rule; fallback camera check if missing data.
* **Deps:** CIR-12

**CIR-44** – Group Challenge "Do It Together" Bonus

* **Type:** Story • **SP:** 2 • **Labels:** challenges
* **AC:** If ≥2 circle members pass same challenge in same day → +15 each.
* **Deps:** CIR-17

**CIR-45** – Leaderboard Themes & Crowns

* **Type:** Task • **SP:** 1 • **Labels:** leaderboard
* **AC:** Crown badges for top-3; theme for weekly winner.
* **Deps:** CIR-18

**CIR-46** – Wrapped: Share Exports (PNG)

* **Type:** Story • **SP:** 2 • **Labels:** ios
* **AC:** Export summary cards to share sheet (PNG).
* **Deps:** CIR-32

**CIR-47** – Data Export JSON Schema + QA

* **Type:** Task • **SP:** 1 • **Labels:** privacy
* **AC:** Export includes challenges, results (booleans), hangouts (centroids, durations), points.
* **Deps:** CIR-30

**CIR-48** – App Review Kit

* **Type:** Task • **SP:** 1 • **Labels:** ios
* **AC:** Review notes (Screen Time fallback, privacy page), demo video, permission rationale.
* **Deps:** CIR-37

---

## Definition of Done (for all stories)

* Unit tests for domain logic (≥1 per service).
* Meets Acceptance Criteria; manual QA pass on physical devices.
* No new critical issues in Crash/OSLog.
* Power profile verified (where applicable).
* App Privacy labels updated if data flows changed.
* Accessible copy and permission rationale reviewed.

---

## CSV Import Format (for Jira/Linear)

```csv
Issue Key,Issue Type,Summary,Description,Story Points,Labels,Sprint,Epic,Acceptance Criteria,Dependencies
CIR-1,Task,App Project Bootstrap,"Create Xcode project, bundle IDs (Debug/Prod), targets, schemes, SwiftPM deps.",2,ios,Sprint 1,E1,"Given I open the project, Then I can build & run on device iOS 16.4+. And schemes Circle-Debug and Circle-Release exist.",
CIR-2,Story,Core Data Model (entities + migrations),"Implement Core Data entities: User, Circle, Membership, Challenge, ChallengeResult, HangoutSession, HangoutParticipant, PointsLedger, LeaderboardSnapshot, Forfeit, WrappedStats, ConsentLog, Device, ChallengeTemplate.",5,coredata,Sprint 1,E1,"Given I run unit tests, Then CRUD succeeds for each entity. And lightweight migration enabled.",CIR-1
CIR-3,Story,CloudKit Mirroring via NSPersistentCloudKitContainer,"Set up CloudKit mirroring with NSPersistentCloudKitContainer",3,"cloudkit,coredata",Sprint 1,E1,"Given iCloud signed-in device, Then records mirror to Private & Shared DBs. And automaticallyMergesChangesFromParent = true.",CIR-2
CIR-4,Task,Build Config & Capabilities,"Configure app capabilities and build settings",2,ios,Sprint 1,E1,"iCloud(CloudKit), Background Modes (location/fetch/processing), HealthKit, Push, Sign in with Apple enabled. No BLE background modes.",CIR-1
CIR-5,Story,Sign in with Apple,"Implement Apple ID authentication",2,auth,Sprint 1,E2,"Given user signs in, Then hashed subject ID stored (salt in Secure Enclave). Logout clears local store & CK references.",CIR-3
CIR-6,Story,Progressive Permissions Flow (When-In-Use → Always),"Implement progressive permission request flow",3,"privacy,location",Sprint 1,E2,"Given first run, Then When-In-Use requested with rationale. Given meaningful use shown, Then Always upgrade prompt with explainer. If denied, degraded mode accessible.",CIR-5
CIR-7,Task,Permissions Manager + ConsentLog,"Create permissions manager with consent logging",2,privacy,Sprint 1,E2,"ConsentLog writes entries per permission grant/deny.",CIR-2
CIR-8,Story,Location Service (SLC + deferred + accuracy escalation),"Implement location service with Significant Location Change",5,"location,background",Sprint 1,E3,"Idle: .hundredMeters, SLC/deferred. Candidate/Active: .nearestTenMeters @ 60–90 s.",CIR-6
CIR-9,Story,Geofence Manager (Place goals),"Create geofence management system",3,location,Sprint 1,E3,"Can create geofence (default 75 m), dwell ≥20 min detected, 1 credit/3h.",CIR-8
CIR-10,Story,Hangout Engine v1 (state machine),"Implement hangout detection state machine",5,location,Sprint 1,E3,"Candidate when distance ≤15 m, accuracy ≤30 m, samples ≤2 min old. Active after 60 s continuous; End if >25 m or stale ≥3 min; merge gaps ≤2 min. Per-user durations saved into HangoutParticipant.",CIR-8,CIR-2
CIR-11,Story,Anti-Cheat Heuristics (loc/motion sanity, uptime),"Implement anti-cheat detection",3,"privacy,location,motion",Sprint 1,E3,"If motion==running & GPS stationary >10 min → trigger camera prompt; durations validated using system uptime deltas.",CIR-10,CIR-16
CIR-12,Story,Challenge Templates & Composer,"Create challenge template system",3,challenges,Sprint 1,E4,"Create from presets (Gym, Run, Sleep, Screen Lite, Custom) with params JSON.",CIR-2
CIR-13,Story,Challenge Engine & Scheduling,"Implement challenge engine",3,"challenges,background",Sprint 1,E4,"Daily/weekly windows computed; evaluation hooks exposed.",CIR-12
CIR-14,Story,Location Challenge Verification,"Implement location-based challenge verification",3,"location,challenges",Sprint 1,E4,"Dwell ≥20 min inside geofence with accuracy ≤50 m for ≥80% of window → pass; 1 credit/3h.",CIR-9,CIR-13
CIR-15,Story,Motion Challenge Verification (steps/distance),"Implement motion-based challenge verification",3,"motion,challenges",Sprint 1,E4,"CMPedometer aggregates steps/distance; time windows (e.g., before 8AM) respected.",CIR-13
CIR-16,Task,Motion Activity Classifier,"Create motion activity classification",2,motion,Sprint 1,E4,"Walking/Running detection via CMMotionActivityManager; stored samples for sanity checks.",CIR-15
CIR-17,Story,Points Ledger & Totals,"Implement points system",3,challenges,Sprint 1,E5,"Challenge pass +10, fail −5, group pass +15, hangout +5/5min (cap +60/day), forfeit +5/−10.",CIR-14,CIR-15,CIR-10
CIR-18,Story,Weekly Leaderboard Snapshot,"Create weekly leaderboard system",3,leaderboard,Sprint 1,E5,"Snapshot job at Sun 23:55; deterministic ranks; top-3 crowns.",CIR-17,CIR-31
CIR-19,Story,Forfeit Engine,"Implement forfeit system",3,"forfeits,camera",Sprint 1,E5,"Bottom users assigned forfeit; completion gives +5, miss −10.",CIR-18,CIR-22
CIR-20,Story,Camera Proof Service (AVFoundation),"Implement camera proof system",5,"camera,privacy",Sprint 1,E6,"Live capture (2–3s clip or burst), random liveness prompts (blink/turn/pan), SHA-256 hash stored, media deleted immediately.",CIR-5
CIR-21,Task,Proof UI (modal + prompts + haptics),"Create camera proof UI",2,"camera,ios",Sprint 1,E6,"Modal UX with instruction → capture → verify → success/fail states with haptics.",CIR-20
CIR-22,Task,Proof Hooks in Challenge/Hangout/Anti-Cheat,"Integrate camera proof hooks",2,"camera,challenges",Sprint 1,E6,"Engine can trigger proof check; result updates ChallengeResult or HangoutSession notes.",CIR-20,CIR-13,CIR-11
CIR-23,Story,BGProcessing Rollups,"Implement background processing",2,background,Sprint 1,E7,"Weekly leaderboard, data compaction; respects Low Power Mode.",CIR-18
CIR-24,Story,Local Notifications (reminders, forfeits),"Implement local notifications",2,notifications,Sprint 1,E7,"Challenge window reminders; forfeit deadlines; tappable deep links.",CIR-13,CIR-19
CIR-25,Story,Push via CKSubscriptions,"Implement CloudKit push notifications",3,"cloudkit,cksubscription,notifications",Sprint 2,E7,"Subscriptions for Challenge, Result, Hangout, Forfeit; devices receive pushes on changes.",CIR-3,CIR-9,CIR-13,CIR-10,CIR-19
CIR-26,Story,Focus Sessions + Random Proofs,"Implement Screen Time Lite fallback",3,"screentime-lite,camera",Sprint 2,E8,"User sets 2× blocks/day; random camera prompts; passing both → day pass.",CIR-20,CIR-13
CIR-27,Task,Strict DeviceActivity (feature flag),"Add DeviceActivity feature flag",2,screentime-lite,Sprint 2,E8,"Capability check; shows toggle in Settings if entitlement present; otherwise hidden.",CIR-26
CIR-28,Story,Circle Share (CKShare create/accept),"Implement CloudKit sharing",3,"ckshare,cloudkit",Sprint 2,E9,"Owner creates share; iMessage link; invitee accepts → Membership created; roles supported.",CIR-3,CIR-5
CIR-29,Task,Real-time Updates UI,"Implement real-time UI updates",2,"cloudkit,ios",Sprint 2,E9,"UI reacts to CK change notifications (new challenge/result/hangout/forfeit) without manual refresh.",CIR-25
CIR-30,Story,Privacy Page & Data Controls,"Create privacy settings page",3,privacy,Sprint 2,E10,"Show what's collected (booleans/aggregates), Delete All Data, Export (JSON), Precise Location toggle per circle.",CIR-2,CIR-3
CIR-31,Task,Low Power / Cellular Throttling,"Implement power management",2,perf,Sprint 2,E10,"Sampling rates halved on Low Power; uploads throttled on cellular.",CIR-8
CIR-32,Story,Weekly Summary Cards (stub),"Create weekly summary feature",3,ios,Sprint 2,E11,"Aggregate week: time with friends, top location, challenges done; render 3 shareable cards.",CIR-17,CIR-10
CIR-33,QA,Urban/Indoor Accuracy Tests,"Test location accuracy in various environments",2,"qa,location",Sprint 2,E12,"Pass criteria for downtown, mall, suburb; false positives <5%.",CIR-10
CIR-34,QA,Permission Denial Paths,"Test permission denial scenarios",1,"qa,privacy",Sprint 2,E12,"Degraded modes usable; no crash loops or hard blocks.",CIR-6
CIR-35,QA,Battery Impact Baseline,"Test battery usage",2,perf,Sprint 2,E12,"24h run < 3–5% overhead vs idle baseline, typical usage.",CIR-8,CIR-31
CIR-36,Task,App Privacy Nutrition Labels,"Configure App Store privacy labels",1,privacy,Sprint 2,E12,"App Store privacy answers reflect on-device verification; no media uploads.",CIR-30
CIR-37,Task,TestFlight Internal (build, notes, screenshots),"Prepare TestFlight build",2,ios,Sprint 2,E12,"Build distributed to internal testers; includes permissions explainer & review notes re: Screen Time fallback.",All MVP core
CIR-38,Task,Crash & Log Baseline (OSLog),"Set up logging system",1,ios,Sprint 2,E12,"OSLog categories for services; no PII; symbolicated crash capture.",CIR-1
CIR-39,Task,App Icons & Theming (basic),"Create app icons and theming",1,ios,Sprint 2,E12,"App icons, accent colors, dark mode pass.",
CIR-40,Task,Haptics & Micro-animations,"Implement haptic feedback",1,ios,Sprint 2,E12,"Success/fail haptics; subtle transitions on proof and leaderboard.",CIR-21,CIR-18
```

---

This backlog is **copy-paste ready** for Jira/Linear and includes:

✅ **Complete Epic Structure** (12 epics covering all features)
✅ **Detailed Stories** with Gherkin-style acceptance criteria
✅ **Clear Dependencies** mapped between tickets
✅ **Sprint Planning** (2-week sprints with proper sequencing)
✅ **Story Points** for velocity tracking
✅ **Labels** for filtering and organization
✅ **CSV Import Format** for bulk creation
✅ **Definition of Done** for quality gates

Your development team can now **import this directly** into their project management tool and start coding immediately! 🚀
