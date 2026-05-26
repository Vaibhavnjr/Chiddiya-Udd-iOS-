# Chiddiya Udd iOS

A small native iOS party game based on "Chidya Udd". Players keep fingers on the screen, the app calls out an item, and everyone reacts:

- If it can fly, lift your finger.
- If it cannot fly, keep your finger down.
- Wrong players are eliminated until one winner is left.

The repo/project name uses `Chidya Udd`, while the in-app title currently says `Chiddya Udd`.

## Run It

Open `Chidya Udd.xcodeproj` in Xcode, pick the `Chidya Udd` scheme, choose a simulator or device, then press Run.

Useful Xcode shortcuts:

- `Cmd + R` runs the app.
- `Cmd + U` runs tests.

There are no CocoaPods, Swift packages, or other third-party dependencies.

## Project Shape

This is a UIKit app shell with SwiftUI doing the actual UI.

- `Chidya Udd/Base.lproj/Main.storyboard` starts the app at `GameViewController`.
- `GameViewController.swift` embeds SwiftUI through `UIHostingController`.
- `AppShellView.swift` loads `GameRootView`.
- `Features/Game/` contains the main game screen, state machine, and game phases.
- `Core/Models/` has the simple game data types.
- `Core/Services/` contains haptics, speech, sound, and confetti helpers.
- `UI/` contains theme colors, touch capture, and reusable SwiftUI controls.
- `Chidya UddTests/` and `Chidya UddUITests/` contain the current test targets.

## Main Flow

The game moves through these phases:

`splash -> waitingForPlayers -> countdown -> locked -> callout -> results -> betweenRounds`

From there it either starts the next round, shows `winner`, or briefly shows `allOut` and resets.

The important rules live in `Features/Game/GameViewModel.swift`:

- Minimum players: `2`
- Maximum players: `4`
- Reaction window: `1` second
- Countdown: `3` seconds
- Items are stored in the `gameItems` array as `GameItem(name:canFly:)`

`TouchCaptureView.swift` is the bridge that makes multi-touch work. It receives raw `UITouch` events from UIKit and forwards them to the view model. Each touch becomes a player during setup, and later rounds try to reattach returning touches to the nearest surviving player.

## Key Files

- `GameViewModel.swift`: source of truth for players, phases, timers, answers, elimination, and resets.
- `GameRootView.swift`: renders the screen for each phase and draws the player circles.
- `GamePhase.swift`: enum for every game state.
- `GameModels.swift`: `GameItem`, `GamePlayer`, and `PlayerStatus`.
- `SpeechService.swift`: speaks the current callout using `AVSpeechSynthesizer`.
- `Haptics.swift`: small wrapper around UIKit feedback generators.
- `ConfettiView.swift`: UIKit/Core Animation confetti used on the win screen.
- `GameTheme.swift`: shared colors and the hex color helper.

## Common Changes

- Add or edit callout words in `GameViewModel.gameItems`.
- Change timing constants near the top of `GameViewModel`.
- Change colors in `UI/GameTheme.swift`.
- Change copy/layout in `GameRootView.swift` and `SplashView.swift`.
- Add actual bundled audio files before relying on `SoundManager`; it exists, but the current game loop mainly uses speech and haptics.

## Notes

- Test on a real device when checking gameplay. Simulators are awkward for real multi-touch.
- The app is portrait-only and currently targets iOS `18.5`.
- `GameScene.sks`, `Actions.sks`, `BackgroundView`, `CustomStepper`, and `CustomSegmentedControl` look like leftovers or reusable pieces; they are not part of the current gameplay path.
