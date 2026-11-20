# Wiggle Party

Three short motion party games for a parent and a five-year-old, in one Godot 4 project. Everyone shares one score. Nothing can be lost, and a round always ends on a celebration screen.

Built and smoke-tested on **Godot 4.7.2-stable** (`4.7.2.stable.official.ed1daf0bf`). Art and sound are drawn and synthesized in GDScript. There are no third-party asset packs.

| Game | What you do | Round |
| --- | --- | --- |
| Balloon Bop | Swing a foam bat. Balloons pop into confetti. | 75 seconds |
| Shake the Tree | Shake (or swing) and apples drop into the basket. | 24 seconds |
| Wobbly Wheel | Tilt sideways like a steering wheel and pick up stars. | 45 seconds |

Point and Splash and Tilt Maze are not in this build. The menu only lists the three games above.

Clips of each game, recorded with simulated swings, are in [`docs/media`](docs/media).

## Open it on a Mac

Godot is free. No account.

1. Install Godot 4.7.2 or newer stable 4.7. The editor download is at [godotengine.org](https://godotengine.org/download/macos/), or:

   ```bash
   brew install --cask godot
   ```

   Homebrew’s cask tracks current stable. This project’s `project.godot` asks for the 4.7 feature set. A 4.6 editor will open the scenes and will not have the joypad motion API described below.

2. If macOS blocks the app the first time, right-click Godot in Finder and choose **Open**, then **Open** again.

3. In the editor, **Import** this folder (`project.godot`), then press **F5** (or the play button). The main menu is `scenes/main_menu.tscn`.

The project uses the GL Compatibility renderer so it runs on a Mac and on a machine without a discrete GPU.

## Play with no controller

The menu: left and right arrows (or A and D) move between the three pictures, Enter starts the highlighted one, or press **1**, **2**, or **3**. Click a picture with the mouse.

During a game, player 0 is the coral bat on the right (the parent). Player 1 is the gold bat on the left (the child). Keyboard and mouse drive a player only while that player has no joypad connected.

| | Player 0, parent | Player 1, child |
| --- | --- | --- |
| Swing | Flick the mouse, Space, or left click | F |
| Shake | Waggle the mouse, or R | T |
| Tilt | Arrow keys | W A S D |
| Tap | Space or left click | G |

On the celebration screen, Enter plays again and Escape (or B on a pad) goes home. The mint button is replay. The gold button is the house.

`JOY_PARTY_DEMO=1`, or the user argument `demo`, plays the rounds by itself. That is what the clips in `docs/media` are.

## Pair Joy-Cons on macOS

1. On the Joy-Con, press the small sync button on the rail (between the SL and SR buttons) until the player lights start marching.
2. Open **System Settings → Bluetooth** and click the Joy-Con when it appears.
3. Leave them as two devices. Do not use a grip that presents them to the Mac as one controller if you want one pad per person. The first joypad Godot sees is player 0. The second is player 1. That order is whatever the Mac discovered, and it can change after a restart.

Launch Godot from a terminal if a platform is combining the two Joy-Cons into one gamepad:

```bash
SDL_JOYSTICK_HIDAPI_COMBINE_JOY_CONS=0 /Applications/Godot.app/Contents/MacOS/Godot --path /path/to/this/folder
```

That variable has to be set before Godot starts. Setting it from a script is too late. SDL reads it when the joystick subsystem starts.

Hold **C** for a second with the pad still if you want the official gyro calibration. The game does not require it. It subtracts a slow running bias so a child can start swinging immediately. Gameplay does not wait on `is_joy_motion_sensors_calibrated()`.

## What the motion API actually does

Phone sensors and joypad sensors are different functions.

`Input.get_gyroscope()`, `Input.get_accelerometer()`, and `Input.get_gravity()` are the phone sensors. On macOS, Windows, and Linux they stay at `Vector3.ZERO`.

Joypad motion arrived in Godot 4.7 and is still present in 4.7.2. It is marked experimental. The methods this project calls, all confirmed present on the 4.7.2 binary used to test:

- `Input.has_joy_motion_sensors(device)`
- `Input.set_joy_motion_sensors_enabled(device, true)` (sensors start off, to save battery)
- `Input.is_joy_motion_sensors_enabled(device)`
- `Input.get_joy_gyroscope(device)` in radians per second. X is pitch, Y is yaw, Z is roll, counterclockwise positive, pad held in front of you.
- `Input.get_joy_accelerometer(device)` in m/s², gravity included
- `Input.get_joy_gravity(device)`
- `Input.start_joy_motion_sensors_calibration(device)` / `stop_joy_motion_sensors_calibration` / `is_joy_motion_sensors_calibrated` / clear and get/set calibration
- `Input.get_joy_motion_sensors_rate(device)`

Docs: [Input class, 4.7](https://docs.godotengine.org/en/4.7/classes/class_input.html) and [Controllers, gamepads, and joysticks](https://docs.godotengine.org/en/4.7/tutorials/inputs/controllers_gamepads_joysticks.html).

Godot 4.7.2 bundles SDL 3.2.28 (`thirdparty/sdl` on tag `4.7.2-stable`). The binary contains the HIDAPI switch hints `SDL_JOYSTICK_HIDAPI_JOY_CONS`, `SDL_JOYSTICK_HIDAPI_SWITCH`, and `SDL_JOYSTICK_HIDAPI_COMBINE_JOY_CONS`.

### What works on a Mac, and what does not

Buttons and sticks work. Pair the Joy-Con, and Godot reports it as a normal joypad. Stick flicks, stick tilt, and every face button, shoulder, d-pad direction, and trigger count as play. That path is the one to expect on a Mac.

Gyro and accelerometer usually do not. Apple’s Game Controller / MFi path reports buttons and sticks and does not report the Joy-Con IMU. `has_joy_motion_sensors()` comes back false, the game keeps running on the stick and buttons, and the two dots under the menu title stay hollow.

SDL’s HIDAPI driver can read a Joy-Con IMU, including on macOS in some setups, but macOS and SDL both want the HID device. Bluetooth Joy-Con accelerometer calibration was wrong until SDL 3.3 (November 2025, [libsdl-org/SDL#14377](https://github.com/libsdl-org/SDL/issues/14377)). Godot 4.7.2 is on SDL 3.2.28, which is older than that fix. If a future Godot build ships SDL 3.3 or newer, enable sensors the same way this project already does and re-check `has_joy_motion_sensors()` on a paired Joy-Con. Do not assume a Mac paired through System Settings will start reporting gyro just because the methods exist.

When sensors are present, a swing is about 1.7 rad/s (roughly a quarter turn per second) and a shake is about 2.2 rad/s or three direction reversals. Gravity of about 4.2 m/s² of sideways component, around 25 degrees of roll, is full steering lock. Thresholds are in `scripts/motion_input.gd` and are meant for a small wrist.

Individual Joy-Cons: SDL exposes the standard gyro and accelerometer when there is no parent device, or when the device is the right Joy-Con. A combined pair also exposes `GYRO_L` / `GYRO_R`, which Godot’s API does not surface separately. Two players need two devices. Keep the combine flag off.

### JoyShockMapper

[JoyShockMapper](https://github.com/Electronicks/JoyShockMapper) is free and open source, and it maps gyro to mouse movement. Official builds are Windows and Linux. There is no official macOS build ([issue #67](https://github.com/Electronicks/JoyShockMapper/issues/67) is still open). On Windows or Linux, `GYRO_SENS` plus `GYRO_ON = GYRO_ALWAYS` turns a swing into a mouse flick, which this project already treats as a swing, and a waggle into a shake. If a joypad is also connected, set `JOY_PARTY_FORCE_MOUSE=1` so the mouse still drives player 0.

This project does not use Steam Input.

## Check it without opening the editor

Headless import and the scene smoke test:

```bash
godot --headless --path . --import
godot --headless --path . --audio-driver Dummy res://tests/smoke_test.tscn
```

The smoke test loads the menu and each game, checks that the 4.7 joypad motion methods exist, and feeds gyro, mouse, stick, gravity, and button events through `MotionInput`. It prints `SMOKE PASS` and exits 0.

To re-record the clips (xvfb, software OpenGL, ffmpeg):

```bash
bash tools/capture_media.sh
```

That writes PNG, GIF, and MP4 files into `docs/media`. `JOY_PARTY_DEMO=1` is set for the three games so the bats, the tree, and the car play themselves.

## Known blockers

- On a Mac paired through System Settings, plan on buttons and sticks. Gyro is a Godot 4.7 API that the Mac Game Controller path does not fill in for a Joy-Con.
- Godot 4.7.2’s bundled SDL 3.2.28 predates the SDL 3.3 Bluetooth Joy-Con accelerometer calibration fix. A HIDAPI path that does report sensors can still have a bad accel calibration until Godot ships a newer SDL.
- Combined Joy-Cons show up as one pad. Set `SDL_JOYSTICK_HIDAPI_COMBINE_JOY_CONS=0` before launch if you need two players from two Joy-Cons.
- Which physical Joy-Con is player 0 depends on discovery order.
- JoyShockMapper has no macOS build.
- Shipping this on a real Nintendo Switch needs Nintendo developer-program approval, a dev kit, and a console port of Godot. This project does not attempt that.

## Layout

```
project.godot
scenes/          main menu and one scene per game
scripts/         MotionInput and AudioFx autoloads, drawing, each game
tests/           headless smoke test
tools/           xvfb movie capture
docs/media/      menu still, and a still, GIF, and MP4 of each game
```
