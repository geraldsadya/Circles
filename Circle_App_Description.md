# 📱 **App Name: Circle**

### *"Social life, verified."*

---

## 🔥 1. **Core Concept**

Circle is an **iPhone-exclusive social accountability app** that combines **habit tracking**, **real-world verification**, and **social competition**.
It turns what people *say* they'll do into visible proof of what they *actually* do — all through the sensors, data, and camera already built into every iPhone.

Unlike typical tracking or habit apps, Circle doesn't rely on self-reporting or uploads.
It **verifies behavior automatically and securely** using local phone data (like step count, motion, and location), and shares *results*, not private data, with your chosen friends.

Every friend group becomes a **circle** where members:

* Post real-world challenges ("Go to the gym 4 days this week," "Sleep before 11," "Less than 2 hours of screen time today")
* Earn or lose points based on whether their actions are verified
* Hang out in real life (tracked automatically)
* See their rankings on a shared leaderboard
* Receive yearly "Circle Wrapped" summaries showing time spent together, most common activities, and personal highlights.

---

## 🧠 2. **App Purpose**

The goal of Circle is to **make discipline social**.
By blending social interaction, gamified accountability, and verified real-life behavior, Circle helps users:

* Build consistency around fitness, health, and habits
* Strengthen friendships through real-world time together
* Reduce digital "flexing" by creating a network of *proof, not posts*

---

## ⚙️ 3. **Key Features Overview**

| Feature                | Description                                                                                               |
| ---------------------- | --------------------------------------------------------------------------------------------------------- |
| **Circles**            | Private friend groups (like "Find My") where members share goals, progress, and verification data.               |
| **Challenges**         | Custom or preset challenges you and your circle create — e.g., "Gym 4x/week" or "Screen time < 2h today." |
| **Circle Verification** | Automatic confirmation via iPhone's built-in sensors (location, motion, health, screen time).             |
| **Camera Check-ins**      | Optional live camera "check-in" (no gallery access, no uploads).                                          |
| **Points System**      | Earn points for verified goals, lose them for missed ones.                                                |
| **Leaderboards**       | Ranks members weekly based on points earned.                                                              |
| **Hangout Detection**  | Detects when friends are physically together (<10 m, >5 min) using location + Bluetooth proximity.        |
| **Forfeit System**     | Losers of weekly challenges must complete fun "circle forfeits" (e.g., random live selfie).                |
| **Circle Wrapped**      | Annual recap summarizing friendships, achievements, and shared habits — like Spotify Wrapped.             |
| **Privacy & Security** | All verification done on-device. Only outcomes (✅/❌) are shared; no personal data is uploaded.            |

---

## 🪩 4. **User Experience Flow**

### A. **Onboarding**

1. User signs in via **Apple ID** (no password, full iCloud security).
2. App requests permission for:

   * Location (for hangouts & movement verification)
   * Motion & Fitness (for steps, workouts, runs)
   * Health data (optional sleep tracking)
   * Screen Time data (optional daily use tracking)
   * Camera (for circle forfeits)
3. User creates or joins a **Circle** via:

   * Contact list detection (iPhone-only)
   * iMessage invite link

---

### B. **Creating a Challenge**

1. Tap **"Post a Challenge"**
2. Choose a **category**:

   * Fitness 🏋🏾‍♂️
   * Screen Time 📱
   * Sleep 💤
   * Social / Study / Custom
3. Define parameters:

   * Frequency (daily, weekly, custom)
   * Target (e.g., "Under 2h," "4 sessions," "Before 10 PM")
   * Duration (how long the challenge runs)
4. Choose a **verification method**:

   * Core Motion → counts movement, steps, workouts
   * Core Location → verifies attendance at a specific spot (e.g., gym)
   * HealthKit → sleep times or active minutes
   * Screen Time API → checks daily phone use
   * Camera Check-in → opens live camera for instant check-in
5. Post to the circle — everyone can see and accept the challenge.

---

### C. **Circle Verification**

Each challenge has automatic detection logic:

| Example Challenge      | How It's Verified                                                    |
| ---------------------- | -------------------------------------------------------------------- |
| "Go to the gym"        | Checks location proximity to saved gym spot for ≥ 20 min.            |
| "Run before 8 AM"      | Confirms motion > threshold + GPS movement before 8:00.              |
| "Under 2h screen time" | Reads daily Screen Time via DeviceActivity.                          |
| "Sleep before 11 PM"   | HealthKit sleep start time < 23:00.                                  |
| "Check-in verification"       | Opens camera, requires 3-second selfie or short clip, verified live. |

App marks ✅ *completed* or ❌ *missed* automatically — no manual input needed.

---

### D. **Points System**

Each action affects the user's total points:

| Action                     | Points           |
| -------------------------- | ---------------- |
| Complete challenge         | +10              |
| Miss challenge             | −5               |
| Hangout (with 1+ friends)  | +5 per 5 minutes |
| Group challenge completion | +15              |
| Forfeit completed          | +5 bonus         |
| Forfeit skipped            | −10              |

Points reset weekly to keep competition fresh.

---

### E. **Leaderboards**

Each Circle shows:

* **Top 3** members (with emojis/crowns)
* **Weekly ranking history**
* **Total points all-time**

Winners receive fun *perks*, like:

* "Streak Freeze" (skip one failed challenge)
* "Double Points Day"
* "Crown badge" (visible for a week)

---

### F. **Hangouts**

* When two or more friends are within **10 meters** for **5+ minutes**, Circle logs a "hangout session."
* Time is accumulated into weekly stats:

  * Who you spent the most time with
  * Common locations
  * Total hours together
* Hangouts also generate points automatically (no manual check-ins).

---

### G. **Circle Forfeits**

Each week, users at the bottom of the leaderboard must complete a **random forfeit** to regain points, such as:

* "Take a selfie with the first thing you see."
* "Show your lunch right now."
* "Record a 2-second sound clip of your surroundings."

All check-ins are **live-only**, camera-based, and automatically deleted after verification.

---

### H. **Circle Wrapped (Yearly Summary)**

At year-end, users get a personal "Circle Wrapped" recap with shareable visuals showing:

* Total hours spent with each friend
* Top hangout locations
* Most completed challenges
* Most common activity type
* Longest streaks
* "Circle Partner of the Year" (most time shared)
* "Top 1% most consistent" badge

Each card is beautifully animated and exportable to Instagram/Snap/TikTok.

---

## 🧱 5. **Technical Design (for the Dev Team)**

### Core Frameworks

| Function             | Apple API                                        |
| -------------------- | ------------------------------------------------ |
| Location tracking    | Core Location                                    |
| Proximity detection  | Core Bluetooth (background advertising/scanning) |
| Motion verification  | Core Motion                                      |
| Screen time          | DeviceActivity + FamilyControls                  |
| Sleep & fitness data | HealthKit                                        |
| Live camera check-ins   | AVFoundation                                     |
| Notifications        | UserNotifications                                |
| Background tasks     | BGTaskScheduler                                  |
| Auth & sync          | Sign in with Apple + CloudKit / CoreData         |

---

### Data Flow

1. All data collected stays **on-device**.
2. The app only shares *booleans* or *aggregated values* (e.g., "Completed Gym Challenge," not GPS or photo).
3. Optional iCloud sync for multi-device continuity.

---

### Power Management

* Location polling at low frequency (e.g., every 3–5 minutes) unless "hangout proximity" triggers a live session.
* Bluetooth beacon scanning at low energy mode.
* No constant background camera or sensor access.

---

## 🔒 6. **Privacy & Security**

* No gallery, no uploads, no permanent photo storage.
* No external servers required; uses only iCloud / local storage.
* Users can delete all data instantly.
* Data shared with friends = verification status, not raw data.
* All camera actions are *live-only* and ephemeral.

---

## 🧩 7. **Design Language**

* Minimal Apple-style UI (white space, rounded tiles, Haptic feedback)
* Emoji-rich leaderboards (crowns, flames, streak icons)
* "Circle Cards" (daily summaries with bold typography + animations)
* Live map of last hangout + group activity radar
* Dark mode default

---

## 🪙 8. **Monetization (Future)**

| Tier                 | Features                                                       |
| -------------------- | -------------------------------------------------------------- |
| Free                 | 1 Circle, 5 Challenges, Weekly Leaderboard                     |
| PRO ($1.99/month)    | Unlimited Circles + Wrapped + Custom forfeits + Streak freezes |
| Sponsored Challenges | Brand integrations (Nike, Gymshark, etc.)                      |
| Merchandising        | End-of-year badges, digital collectibles                       |

---

## 💬 9. **Tone & Culture**

Circle is *not another social network.*
It's *real life, gamified.*
It's for friends who **actually do things together**, not just text.
It's fun, competitive, but grounded in *real action.*

**Tagline ideas:**

* "Show up. Get proof."
* "Friends don't cap — they prove it."
* "No posts. Just proof."
* "Circle up. Level up."
* "Real friends, real proof."

---

If you'd like, I can now follow this up with:

* a **visual product map** (screen-by-screen wireframe description),
* and a **technical handoff document** (data models + iOS API usage guide for devs).



need any more information?
