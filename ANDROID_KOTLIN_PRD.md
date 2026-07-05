# Chiddiya Udd Android Product Requirements Document

## 1. Document Purpose

This document defines the product, interaction, visual, animation, game-logic, and technical requirements for implementing the existing **Chiddiya Udd** iOS party game as a native Android application.

The Android implementation must preserve gameplay parity with the current iOS source while using Android-native architecture and APIs:

- Kotlin
- Jetpack Compose
- Unidirectional state flow
- Android `MotionEvent` multitouch input
- Kotlin coroutines
- Android text-to-speech
- Android haptics

This PRD treats the current iOS runtime behavior as the source of truth. The current implementation supports **2–5 players**, even though the repository README currently states a maximum of four.

---

## 2. Product Summary

Chiddiya Udd is a same-device, local multiplayer reaction and elimination game.

All players place one finger on the same phone or tablet screen. The app announces an item. Players must:

- Lift their finger before the reaction deadline if the item can fly.
- Keep their finger down through the reaction deadline if the item cannot fly.

Players who react incorrectly are eliminated. Survivors place their fingers back on the screen for the next round. Each completed round shortens the reaction window until one player remains.

### Primary Product Goal

Create a fast, understandable, and playful physical party-game experience that requires no accounts, network connection, menus, or individual devices.

### Core Experience Principles

- The screen must respond immediately to every finger.
- Players must understand their status without reading detailed instructions during a round.
- Gameplay must remain fair even when multiple players lift at almost the same time.
- Visuals, speech, and haptics must reinforce the same event.
- The game must be usable on both Android phones and tablets in portrait orientation.

---

## 3. Target Platform and Technical Baseline

### Required Platform

- Android application written in Kotlin.
- UI built with Jetpack Compose and Material 3 foundations.
- Recommended minimum SDK: API 26.
- Target the latest stable Android SDK available when implementation begins.
- Portrait orientation only.
- Full-screen edge-to-edge presentation.
- Hide system bars during active gameplay using immersive mode.
- Support phones and tablets.
- No network connection required.
- No third-party runtime dependency is required for the MVP.

### Recommended Architecture

Use a single-activity Compose application.

```text
MainActivity
└── ChiddiyaUddApp
    └── GameScreen
        ├── TouchCaptureLayer
        ├── PlayerCirclesLayer
        ├── Header
        ├── PhaseContent
        ├── StatusFooter
        ├── AllOutOverlay
        ├── WinnerOverlay
        └── ConfettiLayer
```

Recommended state architecture:

```text
GameViewModel
├── StateFlow<GameUiState>
├── GameReducer / state-transition methods
├── round timing jobs
├── pointer-to-player mapping
└── one-shot effects SharedFlow<GameEffect>
```

Use `StateFlow` for durable screen state and `SharedFlow` or `Channel` for one-shot effects such as speech and haptics.

---

## 4. Naming and Copy

The product name must be standardized before release.

Recommended display name:

**Chiddiya Udd**

The current iOS project contains inconsistent spellings:

- Chidya Udd
- Chiddya Udd
- Chiddiya Udd

All Android app labels, visible headings, accessibility labels, package metadata, and store listing copy must use the approved spelling.

### Required Gameplay Copy

| Context | Text |
|---|---|
| Waiting, zero players | Put fingers to start game |
| Waiting, one player | Need one more finger |
| Countdown subtitle | Hold steady |
| Countdown footer | Game starts in `{n}` secs |
| Locked and ready | Get ready... |
| Locked with missing finger | Put fingers back |
| Between rounds and ready | Next round starts in 1 second |
| Between rounds with missing finger | Survivors, put fingers back |
| All eliminated | Everyone got out! |
| Winner heading | You Win |
| Winner action | Play Again |

Copy should be stored in Android string resources. Do not hardcode visible strings in composables or the ViewModel.

---

## 5. Game Rules

### Player Limits

- Minimum players required to start: `2`
- Maximum registered players: `5`
- Each active pointer represents one player.
- A player may use only one finger.
- Additional pointers beyond the maximum must be ignored.

### Initial Item Pool

| Item | Can Fly |
|---|---|
| Bird | Yes |
| Pigeon | Yes |
| Crow | Yes |
| Eagle | Yes |
| Parrot | Yes |
| Cow | No |
| Dog | No |
| Cat | No |
| Elephant | No |
| Fish | No |

The same item must not be selected in two consecutive rounds. All other items may be selected randomly.

### Reaction Timing

- Initial reaction window: `1,000 ms`
- Reaction-window reduction after every completed round: `100 ms`
- Minimum reaction window: `400 ms`
- A lift at exactly the deadline counts as on time.

Evaluation rules:

```text
Flying item:
  liftTimestamp <= deadline => correct
  no lift by deadline       => wrong

Non-flying item:
  finger remains down through deadline => correct
  liftTimestamp <= deadline             => wrong
```

Use `SystemClock.uptimeMillis()` or `SystemClock.elapsedRealtimeNanos()` for both deadlines and input timestamps. Do not use wall-clock time.

### Round Durations

| Stage | Duration |
|---|---:|
| Splash display before waiting screen | 1,400 ms |
| Initial countdown | 3 seconds |
| All fingers locked before callout | 1,150 ms |
| Results display | 1,450 ms |
| Ready delay between rounds | 1,000 ms |
| All-out screen before reset | 1,800 ms |

---

## 6. Game State Machine

Use an explicit sealed interface or enum for all phases.

```kotlin
sealed interface GamePhase {
    data object Splash : GamePhase
    data object WaitingForPlayers : GamePhase
    data class Countdown(val value: Int) : GamePhase
    data object Locked : GamePhase
    data object Callout : GamePhase
    data object Evaluating : GamePhase
    data object Results : GamePhase
    data object BetweenRounds : GamePhase
    data object AllOut : GamePhase
    data object Winner : GamePhase
}
```

Required flow:

```text
Splash
  -> WaitingForPlayers
  -> Countdown
  -> Locked
  -> Callout
  -> Evaluating
  -> Results
  -> BetweenRounds -> Callout
  -> Winner
  -> AllOut -> WaitingForPlayers
```

### State Transition Requirements

#### Splash

- Show the logo and product name.
- Automatically enter `WaitingForPlayers` after `1,400 ms`.
- Ignore touches during splash.

#### Waiting for Players

- Register each new pointer as a new player until five players exist.
- Show a circle at each pointer position.
- If fewer than two players are down, remain in this phase.
- Once at least two players are down, enter `Countdown`.

#### Countdown

- Display `3`, `2`, then `1`, with one second per value.
- Players may join during the countdown if fewer than five players exist.
- If any pointer is removed, remove that player and restart readiness evaluation.
- If player count falls below two, return to `WaitingForPlayers`.
- At countdown completion, continue only if all registered players are still down.

#### Locked

- Mark all down players as locked.
- If a finger is missing, display its warning state and pause progression.
- When all alive players are down continuously for `1,150 ms`, begin the callout.

#### Callout

- Randomly choose a non-repeating item.
- Set the reaction deadline using monotonic time.
- Speak the item name immediately.
- Give selection haptic feedback.
- Track each finger lift independently.
- At the deadline, evaluate all players who have not lifted.

#### Evaluating and Results

- Assign every alive player either `Correct` or `Wrong`.
- Reduce the reaction window by `100 ms`, respecting the `400 ms` minimum.
- Display result states for `1,450 ms`.
- Eliminate all wrong players after the result display.

#### Between Rounds

- Preserve the screen positions of surviving players.
- Survivors who lifted must place their fingers back near their prior circles.
- Reattach a new pointer to the nearest alive player currently missing a finger.
- When every survivor is down continuously for `1,000 ms`, begin the next callout.

#### Winner

- Trigger when exactly one alive player remains.
- Mark the remaining player as the winner.
- Show winner screen and confetti.
- Keep the screen visible until `Play Again` is selected.

#### All Out

- Trigger when no alive players remain.
- Show the all-out overlay for `1,800 ms`.
- Automatically reset to `WaitingForPlayers`.

---

## 7. Data Model

Recommended models:

```kotlin
data class GameItem(
    val name: String,
    val canFly: Boolean,
)

enum class PlayerStatus {
    REGISTERING,
    READY,
    LOCKED,
    NEEDS_FINGER_BACK,
    CORRECT,
    WRONG,
    ELIMINATED,
    WINNER,
}

data class GamePlayer(
    val id: String,
    val pointerId: Int?,
    val position: Offset,
    val status: PlayerStatus,
    val isFingerDown: Boolean,
    val isAlive: Boolean,
)

data class GameUiState(
    val phase: GamePhase,
    val players: List<GamePlayer>,
    val activeItem: GameItem?,
    val reactionWindowMs: Long,
    val showConfetti: Boolean,
)
```

All state exposed to Compose must be immutable. Update collections by producing new values.

---

## 8. Multitouch Interaction Specification

Multitouch accuracy is the most important technical requirement.

### Input Layer

Use a full-screen Compose layer with `pointerInteropFilter` or an Android `View` hosted through `AndroidView`. The layer must consume raw `MotionEvent` input and support simultaneous pointers.

Do not model the game through independent clickable composables. Android pointer IDs must remain authoritative.

### Event Handling

Handle:

- `ACTION_DOWN`
- `ACTION_POINTER_DOWN`
- `ACTION_MOVE`
- `ACTION_UP`
- `ACTION_POINTER_UP`
- `ACTION_CANCEL`

For every down or up action, use `actionIndex` to identify the changed pointer. For move events, update every active pointer included in the event.

### Pointer Mapping

Maintain:

```kotlin
MutableMap<Int, PlayerId>
```

Android pointer IDs may be reused after a pointer is lifted. Remove mappings immediately on up or cancel.

### Registration Rules

- In `WaitingForPlayers` and `Countdown`, a new pointer creates a new player.
- During `Locked` and `BetweenRounds`, a new pointer must attach to the nearest alive player whose finger is missing.
- During `Results`, a new pointer may attach only to the nearest correct, alive player whose finger is missing.
- Ignore new pointers in `Splash`, `Callout`, `Evaluating`, `AllOut`, and `Winner`.

### Position Rules

- Store pointer position in screen-local pixels.
- Draw each player circle centered on its stored position.
- Update the position on every move event.
- Preserve the last position after a lift so a returning survivor can be matched to the nearest prior circle.

### Cancellation and Lifecycle

On `ACTION_CANCEL`, app backgrounding, activity pause, focus loss, or system interruption:

- Cancel active round jobs and speech.
- Treat all current pointers as lifted.
- Do not evaluate interrupted touches as valid reactions.
- Recommended behavior: reset to `WaitingForPlayers` when the app becomes active again.

This Android behavior must be explicitly implemented because active pointers cannot safely survive activity lifecycle interruption.

---

## 9. Visual Design System

### Color Tokens

| Token | Value | Usage |
|---|---|---|
| Background | `#62CEB5` | Full-screen background |
| Primary | `#ED2126` | Logo, registering players, primary action |
| Surface | `#FFFFFF` | Cards, callout capsule, success circle |
| Text Primary | `#1F2328` | Main dark text and locked circle |
| Text Secondary | `#1F2328` at 68% | Secondary instructions |
| Text on Primary | `#FFFFFF` | Text/icons on red or dark surfaces |
| Success | `#16A34A` | Correct border, checkmark, success glow |
| Warning | `#FFD54A` | Missing-finger dashed border |
| Error | `#ED2126` | Wrong circle and error emphasis |
| Border | `#FFFFFF` at 64% | Default circle outlines |
| Shadow | `#1F2328` at 16% | Cards and circles |

### Typography

Use a rounded sans-serif font with a playful but highly legible appearance.

Recommended Android choice:

- Bundle **Nunito Sans** or **Nunito** as a font resource.
- Use `FontWeight.ExtraBold` or `Black` for major game text.
- Use `Bold` for supporting status text.

Do not depend on a device-specific rounded system font because typography would vary across manufacturers.

| Element | Size | Weight | Alignment |
|---|---:|---|---|
| Header title | 22 sp | Black | Center |
| Waiting prompt | 30 sp | Black | Center |
| Countdown number | 118 sp | Black | Center |
| Countdown subtitle | 22 sp | Bold | Center |
| Locked prompt | 34 sp | Black | Center |
| Callout item | 68 sp, scale down to fit | Black | Center |
| Between-round prompt | 30 sp | Black | Center |
| All-out heading | 38 sp | Black | Center |
| Winner heading | 58 sp | Black | Center |
| Footer status | 18 sp | Bold | Center |
| Play Again label | 20 sp | Black | Center |

### Shape and Elevation

- General large corner radius: `20 dp`
- Callout background: capsule / fully rounded
- Winner card radius: `32 dp`
- Play Again button: capsule
- Player circles: perfect circles
- Callout capsule padding: `28 dp` horizontal, `18 dp` vertical
- Winner card elevation should visually approximate a `24 dp` blurred shadow with `12 dp` vertical offset.
- Player circles should visually approximate a `14 dp` shadow with `8 dp` vertical offset.

### Screen Layout

- Fill the full display with the mint background.
- Place touch capture behind all visual content but above the background.
- Place player circles above touch capture.
- Keep text and overlays non-interactive except `Play Again`.
- Header top padding: `18 dp` plus safe inset.
- Center content horizontal padding: `28 dp`.
- Footer horizontal padding: `24 dp`.
- Footer bottom padding: `34 dp` plus safe inset.
- Preserve at least `40 dp` between the header and center content.

### Header

- Center horizontally.
- Show a filled bird icon followed by `Chiddiya Udd`.
- Icon size: approximately `22 dp`.
- Icon color: primary red.
- Title color: text primary.

Use an approved vector asset for the bird. Do not rely on an unavailable iOS SF Symbol equivalent.

---

## 10. Player Circle Specification

### Circle Diameter

Calculate from the shortest screen side:

```text
1 player: shortestSide / 3.25
2 players: shortestSide / 3.65
3 players: shortestSide / 4.05
4 players: shortestSide / 4.45
5 players: shortestSide / 4.80
```

Clamp final diameter to:

- Minimum: `84 dp`
- Maximum: `134 dp`

### Player Status Appearance

| Status | Fill | Border | Scale | Opacity | Symbol |
|---|---|---|---:|---:|---|
| Registering | Primary red | White 64%, 3 dp | 1.00 | 1.00 | None |
| Ready | White 86% | White 64%, 3 dp | 1.00 | 1.00 | None |
| Locked | Text primary | White 64%, 3 dp | 1.00 | 1.00 | None |
| Needs finger back | White 62% | Warning dashed, 4 dp | 0.92 | 0.68 | None |
| Correct | White | Success, 4 dp | 1.08 | 1.00 | Checkmark |
| Wrong | Error red | Default border | 1.08 during results | 1.00 | X |
| Winner | White | Success, 4 dp | 1.08 | 1.00 | Checkmark |
| Eliminated | Transparent | None | Exit animation | 0.00 | None |

Status symbol size must be `36%` of circle diameter.

### Dashed Warning Border

- Stroke width: `4 dp`
- Dash length: `8 dp`
- Gap length: `8 dp`
- Rounded stroke caps

---

## 11. Animation Specification

Animations must remain smooth while five fingers are moving. Prefer Compose graphics transforms over relayout-heavy animation.

Respect the Android system animator-duration scale. When animations are disabled, all state transitions must remain understandable.

### Splash Entrance

- Initial logo/title scale: `0.92`
- Final scale: `1.00`
- Initial alpha: `0`
- Final alpha: `1`
- Spring duration feel: approximately `550 ms`
- Spring damping ratio: approximately `0.72`
- Start immediately when splash is composed.

### Player Circle Entrance and Exit

- Entrance starts at scale `0.58` and alpha `0`.
- Animate to scale `1.00` and alpha `1`.
- Exit reverses to scale `0.58` and alpha `0`.
- Use a responsive spring approximating:
  - response: `320 ms`
  - damping ratio: `0.78`

### Player Movement

- Animate displayed circle position toward the latest pointer position over `180 ms`.
- Use ease-in-out interpolation.
- Input state itself must update immediately; only the visual position is eased.
- If visual lag makes the circle feel detached from the finger on Android devices, reduce duration to `80–120 ms` after usability testing. Input correctness takes priority over exact visual parity.

### Registration Ripple

Show only while a finger is down during `WaitingForPlayers` or `Countdown`.

- Ring diameter: `1.35 ×` player circle diameter.
- Ring stroke: white at 42%, `8 dp`.
- Initial scale: `0.72`.
- Final scale: `1.22`.
- Initial alpha: `0.72`.
- Final alpha: `0`.
- Duration: `1,050 ms`.
- Easing: ease-out.
- Repeat forever without reversing.

### Status Transition

Animate circle fill, scale, alpha, border, shadow, and symbol changes using a spring approximating:

- response: `280 ms`
- damping ratio: `0.74`

The checkmark and X must scale and fade in and out with the status transition.

### Countdown Number

Each number change must visibly animate.

Recommended implementation:

- Outgoing number moves upward `12 dp` and fades to `0`.
- Incoming number starts `12 dp` below and fades to `1`.
- Duration: `220 ms`.
- Easing: fast-out-slow-in.

### Callout Presentation

For Android implementation quality, animate each new callout capsule:

- Start at scale `0.92` and alpha `0`.
- Animate to scale `1.00` and alpha `1`.
- Duration: `180 ms`.
- Use a lightly overshooting spring.

The item text and speech must begin from the same callout event. Do not wait for the visual animation to finish before speaking.

### All-Out Overlay

- Fade dark overlay from alpha `0` to `0.92` over `180 ms`.
- Scale the X icon and heading from `0.92` to `1.00` using a short spring.
- Automatically dismiss through game-state reset after `1,800 ms`.

### Winner Screen

- Fade the winner screen in over `220 ms`.
- Animate the winner card from scale `0.92` to `1.00` using a spring.
- Decorative background birds remain static.
- Start confetti as soon as `Winner` is entered.

### Confetti

Render a short burst across the full width above the top edge.

Required colors:

- `#ED2126`
- `#62CEB5`
- `#FFFFFF`
- `#FFD54A`
- `#1F2328`

Particle requirements:

- Use rectangle and square particles.
- Approximate source sizes: `12 × 6 dp` and `8 × 8 dp`.
- Emit for `100 ms`, then stop creating new particles.
- Existing particles may remain alive for up to `10 seconds`.
- Initial downward velocity: approximately `200 dp/s`.
- Velocity variation: approximately `±100 dp/s`.
- Downward acceleration: approximately `150 dp/s²`.
- Add random spin around `3.5 radians/s`, with variation.
- Add horizontal spread and random scale variation.

Implement using a custom Compose `Canvas` particle system or a lightweight custom Android `View`. The animation must not block the main thread.

### Play Again Press Interaction

- Scale button from `1.00` to `0.95` while pressed.
- Use a spring approximating `300 ms` response and `0.60` damping ratio.
- Trigger reset when the pointer is released inside the button.

---

## 12. Haptics and Speech

### Haptic Mapping

Use `View.performHapticFeedback` and `VibratorManager` where necessary. Respect device settings and hardware support.

| Event | Required Feedback |
|---|---|
| New finger registered or reattached | Light impact |
| Players become locked | Medium impact |
| Callout begins | Selection tick |
| Correct lift | Success-style feedback |
| Wrong lift | Error-style feedback |
| Evaluation with any wrong players | Error-style feedback |
| Evaluation with all correct players | Success-style feedback |
| Winner | Success-style feedback |
| All out | Error-style feedback |

Do not vibrate continuously while fingers move.

### Text-to-Speech

Use Android `TextToSpeech`.

Requirements:

- Locale: `Locale.US`
- Speech rate: approximately `1.08`
- Pitch: `1.0`
- Stop or flush existing speech before speaking a new item.
- Use `QUEUE_FLUSH`.
- Initialize TTS before gameplay begins.
- If TTS is unavailable, continue gameplay visually without blocking.
- Shut down the TTS engine when the owning lifecycle is destroyed.

---

## 13. Accessibility and Usability

This is a visual and physical multitouch game, so full TalkBack gameplay parity may not be possible. The implementation must still provide sensible accessibility support.

- Give the logo and product title an accessibility label.
- Announce countdown values and callout items through live-region semantics where practical.
- Give `Play Again` a clear button role and label.
- Never communicate correct, wrong, or missing-finger status by color alone; always use checkmark, X, border style, scale, or text.
- Maintain readable contrast for all text.
- Support Android font scaling up to `1.3×` without clipping critical game text.
- Callout text may scale down to fit one line but must not become smaller than approximately `40 sp`.
- Touch circles are not buttons and should not be exposed as individually clickable accessibility nodes.
- Keep all critical prompts centered and visible around arbitrary finger positions.

---

## 14. Error Handling and Edge Cases

### Required Behaviors

- Ignore a sixth or later simultaneous pointer.
- Ignore duplicate down events for an already-mapped pointer ID.
- Remove a pointer mapping on up or cancel.
- Never eliminate an already eliminated player twice.
- Do not start a callout with fewer than two alive players.
- Cancel the locked timer whenever any alive finger lifts.
- Cancel the between-round timer whenever any survivor lifts.
- A lift received after the reaction deadline must not count as a valid flying-item reaction.
- A lift exactly at the deadline counts as on time.
- Multiple players may be eliminated in the same round.
- If everyone is eliminated, do not select an arbitrary winner.
- Prevent the same callout item from appearing twice consecutively.
- Reset reaction speed to `1,000 ms` on a new game.
- Cancel all coroutines when resetting or leaving the screen.
- Avoid stale delayed jobs changing the state after a reset.
- Handle TTS initialization failure gracefully.
- Handle devices without advanced haptic capabilities gracefully.

### Fairness Requirement

Input timestamps must be evaluated from the raw motion event, not from when Compose finishes recomposition or when a coroutine receives the event.

---

## 15. Performance Requirements

- Target 60 frames per second during five-finger movement and ripple rendering.
- Do not allocate large objects on every pointer move.
- Do not launch a new coroutine for every move event.
- Keep game rule evaluation off rendering code paths.
- Recompose only affected visual layers when possible.
- Confetti must not delay touch handling.
- TTS and haptic calls must not block the UI thread.
- App cold start should reach the splash screen in under two seconds on a typical supported device.

---

## 16. Testing Requirements

### Unit Tests

Test pure game logic independently from Android UI:

- Initial phase is splash.
- Reset restores initial reaction window.
- Reaction window decreases from `1,000 ms` to `400 ms`.
- Reaction window never drops below `400 ms`.
- Flying lift before deadline is correct.
- Flying lift exactly at deadline is correct.
- Flying lift after deadline is wrong.
- Non-flying lift before or at deadline is wrong.
- Non-flying finger held through deadline is correct.
- Same item is not selected twice consecutively.
- Multiple wrong players are eliminated together.
- One survivor produces winner state.
- Zero survivors produces all-out state.
- Missing fingers block locked and between-round progression.
- Reset cancels stale state transitions.

### ViewModel Coroutine Tests

Use `kotlinx-coroutines-test` and a test dispatcher.

- Verify all exact phase delays.
- Verify countdown cancellation and restart.
- Verify callout deadline evaluation.
- Verify results duration before elimination.
- Verify all-out automatic reset.

### Multitouch Instrumentation Tests

Automated multitouch injection can vary by test environment. Include instrumentation coverage where reliable and mandatory real-device manual testing.

Test:

- Two through five simultaneous players.
- Player added during countdown.
- Player removed during countdown.
- Two players lifting nearly simultaneously.
- Correct survivor finger reattachment.
- Nearest-player matching when multiple survivors are missing fingers.
- Pointer cancellation.
- App background and foreground during every phase.

### Visual Tests

Create screenshot tests for:

- Splash
- Waiting with zero, one, and five players
- Countdown
- Locked
- Correct and wrong results
- Missing-finger state
- All-out overlay
- Winner screen

Test at representative phone and tablet sizes.

---

## 17. Acceptance Criteria

The Android implementation is ready for release when:

1. Two to five people can complete a full game on one Android phone or tablet.
2. Every simultaneous pointer is tracked independently and reliably.
3. Flying and non-flying reactions are evaluated from raw event timestamps.
4. The reaction window starts at one second and reaches, but never passes, 400 milliseconds.
5. Wrong players are eliminated after the result display.
6. Survivors can reattach their fingers near their previous positions.
7. Exactly one survivor shows the winner screen and confetti.
8. Zero survivors shows the all-out screen and resets automatically.
9. All fonts, colors, spacing, circle states, animations, speech, and haptic events match this PRD.
10. The app remains responsive during five-finger movement and confetti.
11. Lifecycle interruptions do not leave stale timers, speech, or pointer mappings active.
12. Unit, coroutine, screenshot, and real-device multitouch test plans pass.

---

## 18. Recommended Implementation Sequence

1. Create project foundation, theme tokens, typography, and full-screen portrait activity.
2. Implement immutable models, phase state machine, and pure game rules.
3. Add coroutine-driven timing and cancellation behavior.
4. Implement raw `MotionEvent` capture and pointer-to-player mapping.
5. Render player circles and all status appearances.
6. Implement phase-specific text and screen overlays.
7. Add speech and haptic one-shot effects.
8. Add all specified animations.
9. Add confetti particle rendering.
10. Add lifecycle interruption handling.
11. Complete automated tests.
12. Validate gameplay on multiple real Android phones and at least one tablet.

---

## 19. Future Enhancements Outside MVP

These items are intentionally excluded from parity implementation but may be considered later:

- First-launch tutorial or animated rules screen
- Hindi voice and localized item sets
- Player-specific colors or numbers
- Custom round categories
- Difficulty selection
- Sound effects and music
- Score-based mode
- Larger item library
- Analytics
- Online or multi-device multiplayer

---

## 20. Exhaustive iOS Parity Constants

This appendix is the definitive constant inventory for strict visual and behavioral parity with the current iOS implementation. When a value in this appendix conflicts with a recommendation elsewhere in the PRD, use this appendix for parity builds.

### Game Logic Constants

| Constant | Value |
|---|---:|
| Minimum players | `2` |
| Maximum players | `5` |
| Countdown start value | `3` |
| Splash duration | `1,400 ms` |
| Locked-ready duration | `1,150 ms` |
| Results duration | `1,450 ms` |
| Between-round ready delay | `1,000 ms` |
| All-out duration | `1,800 ms` |
| Initial reaction window | `1,000 ms` |
| Minimum reaction window | `400 ms` |
| Reaction-window reduction | `100 ms` |

### Complete Game Item Constants

```kotlin
val gameItems = listOf(
    GameItem(name = "Bird", canFly = true),
    GameItem(name = "Pigeon", canFly = true),
    GameItem(name = "Crow", canFly = true),
    GameItem(name = "Eagle", canFly = true),
    GameItem(name = "Parrot", canFly = true),
    GameItem(name = "Cow", canFly = false),
    GameItem(name = "Dog", canFly = false),
    GameItem(name = "Cat", canFly = false),
    GameItem(name = "Elephant", canFly = false),
    GameItem(name = "Fish", canFly = false),
)
```

### Complete Color Constants

| Kotlin Token | Hex / Alpha |
|---|---|
| `Background` | `#62CEB5` |
| `Primary` | `#ED2126` |
| `Surface` | `#FFFFFF` |
| `TextPrimary` | `#1F2328` |
| `TextSecondary` | `#1F2328` at `0.68` alpha |
| `TextOnPrimary` | `#FFFFFF` |
| `TextOnSurface` | `#1F2328` |
| `Success` | `#16A34A` |
| `Warning` | `#FFD54A` |
| `Error` | `#ED2126` |
| `Border` | `#FFFFFF` at `0.64` alpha |
| `Shadow` | `#1F2328` at `0.16` alpha |
| `CalloutSurface` | `#FFFFFF` at `0.92` alpha |
| `ReadyCircleFill` | `#FFFFFF` at `0.86` alpha |
| `MissingFingerFill` | `#FFFFFF` at `0.62` alpha |
| `MissingFingerOverallOpacity` | `0.68` |
| `RegistrationRippleStroke` | `#FFFFFF` at `0.42` alpha |
| `WrongShadow` | `#ED2126` at `0.28` alpha |
| `CorrectShadow` | `#16A34A` at `0.34` alpha |
| `AllOutOverlay` | `#1F2328` at `0.92` alpha |
| `WinnerBirdFlock` | `#FFFFFF` at `0.18` overall alpha |
| `WinnerCardSurface` | `#FFFFFF` at `0.94` alpha |

### Complete Screen Layout Constants

| Element | Constant |
|---|---:|
| Shared general corner radius | `20 dp` |
| Header top padding | `18 dp` |
| Header icon-title spacing | `8 dp` |
| Minimum space below header | `40 dp` |
| Center-content horizontal padding | `28 dp` |
| Minimum space below center content | `28 dp` |
| Footer horizontal padding | `24 dp` |
| Footer bottom padding | `34 dp` |
| Footer vertical text padding | `12 dp` |
| Empty footer reserved height | `44 dp` |
| All-out overlay content padding | `28 dp` |
| All-out icon-heading spacing | `14 dp` |
| Winner content spacing | `26 dp` |
| Winner card general padding | `30 dp` |
| Winner card additional vertical padding | `14 dp` |
| Winner card corner radius | `32 dp` |
| Play Again top padding | `8 dp` |
| Play Again horizontal padding | `26 dp` |
| Play Again vertical padding | `15 dp` |

Safe-area or system-inset padding must be added to the parity values where required on Android.

### Complete Typography and Icon Constants

All text uses a rounded design on iOS. Use the bundled Android rounded font selected in this PRD.

| Element | Size | Weight |
|---|---:|---|
| Splash bird icon | `72 sp` equivalent | Black |
| Splash title | `42 sp` | Black |
| Header bird icon | `22 sp` equivalent | Black |
| Header title | `22 sp` | Black |
| Waiting prompt | `30 sp` | Black |
| Countdown number | `118 sp` | Black |
| Countdown subtitle | `22 sp` | Bold |
| Locked prompt | `34 sp` | Black |
| Callout item | `68 sp` | Black |
| Between-round prompt | `30 sp` | Black |
| All-out center text | `38 sp` | Black |
| All-out overlay icon | `70 sp` equivalent | Black |
| All-out overlay heading | `38 sp` | Black |
| Status footer | `18 sp` | Bold |
| Winner bird icon | `86 sp` equivalent | Black |
| Winner heading | `58 sp` | Black |
| Play Again label and icon | `20 sp` | Black |

The callout item is limited to one line and may scale down to `58%` of its original text size in the current iOS implementation.

### Complete Player Circle Constants

| Constant | Value |
|---|---:|
| Minimum diameter | `84 dp` |
| Maximum diameter | `134 dp` |
| One-player divisor | `3.25` |
| Two-player divisor | `3.65` |
| Three-player divisor | `4.05` |
| Four-player divisor | `4.45` |
| Five-player divisor | `4.80` |
| Default border width | `3 dp` |
| Correct/winner border width | `4 dp` |
| Missing-finger border width | `4 dp` |
| Missing-finger dash length | `8 dp` |
| Missing-finger dash gap | `8 dp` |
| Player-circle shadow radius | `14 dp` |
| Player-circle shadow X offset | `0 dp` |
| Player-circle shadow Y offset | `8 dp` |
| Status symbol size | `36%` of circle diameter |
| Status-symbol shadow radius | `5 dp` |
| Status-symbol shadow X offset | `0 dp` |
| Status-symbol shadow Y offset | `2 dp` |
| Correct/winner scale | `1.08` |
| Wrong scale during results | `1.08` |
| Missing-finger scale | `0.92` |
| Missing-finger opacity | `0.68` |

### Complete Animation Constants

| Animation | Values |
|---|---|
| Splash | Initial scale `0.92`; initial alpha `0`; spring response `550 ms`; damping `0.72` |
| Circle insertion/removal | Transition scale `0.58` plus alpha; spring response `320 ms`; damping `0.78` |
| Circle status update | Spring response `280 ms`; damping `0.74` |
| Circle position update | Ease-in-out duration `180 ms` |
| Registration ripple frame | `1.35 ×` circle diameter |
| Registration ripple stroke | `8 dp` |
| Registration ripple scale | `0.72` to `1.22` |
| Registration ripple alpha | `0.72` to `0` |
| Registration ripple duration | `1,050 ms`, repeating, no reverse |
| Reusable button press | Scale `1.00` to `0.95`; spring response `300 ms`; damping `0.60` |
| Reusable stepper update | Spring response `300 ms`; damping `0.60` |
| Reusable segmented selection | Spring response `300 ms`; damping `0.70` |

The countdown, callout, all-out, and winner entrance animations recommended earlier in this PRD are Android polish additions. They do not currently have explicit equivalent animations in the iOS source.

### Complete Confetti Constants

| Constant | Value |
|---|---:|
| Emitter Y position | `-50 px` above screen |
| Emitter X position | Screen midpoint |
| Emitter shape | Horizontal line across full screen width |
| Colors | `#ED2126`, `#62CEB5`, `#FFFFFF`, `#FFD54A`, `#1F2328` |
| Shapes per color | One `12 × 6` rectangle and one `8 × 8` square |
| Cell count | `10` |
| Birth rate per cell | `20` |
| Emission duration | `100 ms` |
| Particle lifetime | `10 seconds` |
| Initial velocity | `200` |
| Velocity range | `100` |
| Downward acceleration | `150` |
| Emission longitude | `π` |
| Emission range | `π / 4` |
| Spin | `3.5` |
| Spin range | `1.0` |
| Initial scale | `0.5` |
| Scale range | `0.2` |

Android implementations may convert pixel-based particle dimensions and physics values to density-aware units, but the visual result must remain equivalent.

### Complete Speech Constants

| Constant | Value |
|---|---|
| Language / locale | `en-US` / `Locale.US` |
| Speech rate | `1.08 ×` default |
| Pitch | `1.0` |
| Volume | `1.0` |
| Existing speech behavior | Stop or flush immediately before new speech |

### Winner Decorative Bird Constants

Each decorative bird position is expressed as a fraction of screen width and height.

| Index | X | Y | Size | Rotation |
|---:|---:|---:|---:|---:|
| 1 | `0.14` | `0.16` | `34` | `-18°` |
| 2 | `0.82` | `0.14` | `28` | `22°` |
| 3 | `0.26` | `0.32` | `24` | `10°` |
| 4 | `0.72` | `0.38` | `38` | `-10°` |
| 5 | `0.12` | `0.64` | `30` | `18°` |
| 6 | `0.86` | `0.66` | `26` | `-24°` |
| 7 | `0.36` | `0.82` | `36` | `16°` |
| 8 | `0.68` | `0.86` | `24` | `-8°` |

### Constants Present but Not Used in Current Gameplay

The iOS repository contains these reusable or legacy behaviors, but they are not part of the active gameplay path:

- A reusable button style with a `0.95` pressed scale.
- A custom stepper using a `300 ms`, `0.60` damping spring.
- A custom segmented control using a `300 ms`, `0.70` damping spring.
- A sound manager with convenience names `beep`, `ding`, `success`, and `error`; no matching bundled audio is currently used by the game loop.
- SpriteKit scene files and a simple background view that are not used by the current game screen.
