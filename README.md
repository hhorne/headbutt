# Headbutt

A simple, fast, local-multiplayer headbutting prototype built with LÖVE. Two dudes face off: build charge, snap forward with your head, and send your rival flying.

### How to Play
- Move around, build charge, and release to headbutt.
- You can cancel out of charge to fake or reposition.
- Hits apply knockback based on your charge at release.

### Controls

Keyboard (Player 1)
- Move: W/A/S/D
- Rotate: H (left), L (right)
- Charge: J
- Cancel Charge: K
- Toggle Debug: F1
- Cycle Knockback Preset: F2
- Toggle Charge Input Mode (press/hold): F3
- Hot Reload (when debug on): F5

Gamepad (Player 2)
- Move: Left stick (leftx/lefty) or D-Pad
- Rotate: Right stick X
- Charge: Right Shoulder (RB/R1)
- Cancel Charge: Left Shoulder (LB/L1)

Notes
- Supports keyboard + controller simultaneously for P1 (movement stacks, controller rotation has priority).
- Raw joystick fallback uses axes 1/2 for move, 3 for rotate (no buttons).

### Debug Mode
- Press F1 to toggle. A small debug UI will appear and additional overlays will render.
- F2 cycles knockback presets: GENTLE → BALANCED → STRONG → LEGACY (default at boot is LEGACY).
- F3 toggles charge input mode:
  - press: Tap J/RB to start charging, release starts the snap.
  - hold: Hold J/RB to keep charging, release to snap.
- F5 triggers hot reload; in debug it logs reloaded modules.

Debug overlays include:
- Collision shapes (body OBB, shoulders, head circle, AABBs)
- Arrows for contact normals and vectors for movement/physics
- UI text for internal stats
- Stun fill overlay on bodies while stunned (debug visualization)

### Core Mechanics

Charging
- Charge builds over time with a logarithmic curve up to MAX (configurable).
- Movement is slowed while charging (35% of base speed by default).
- You can cancel the charge at any time before release.

Headbutt (Snap)
- On release, your head snaps forward, then returns.
- Knockback is computed from the charge you had at snap start, using a curve.
- Only targets in front are hittable during the snap.

Stun (debug visualization)
- Successful headbutts apply a short stun to the target and attacker (debug-only effect) for 0.75s by default.
- While stunned you cannot start charging.
- A translucent red body fill indicates stun in debug overlays.

I-Frames (invincibility frames)
- During the forward portion of the snap, brief i-frames are active right before peak forward motion.
- Hits against an invincible target are ignored.
- Timing is configurable via head config (see IFRAME_PRE_PEAK_TIME).

### Tuning (where to change things)
- Movement and charge: `config/movement_config.lua`
  - `MOVEMENT.BASE_MOVE_SPEED`, `CHARGE_MAX`, `CHARGE_RATE`, `CHARGE_MOVE_SPEED_MULT`, `CANCEL_DURATION`
  - Head snap: `HEAD.SNAP_TOTAL_DURATION`, `SNAP_FORWARD_RATIO`, `SNAP_RETURN_EXTRA`, `IFRAME_PRE_PEAK_TIME`
- Knockback: `config/knockback_config.lua`
  - `BASE_SPEED`, `DURATION`, `CURVE_POWER`, `PHYSICS.DECAY_RATE`, presets
- Stun: `config/stun_config.lua`
  - `DURATION` and wobble visuals
- Inputs: `config/input_config.lua`

### Running
- Requires LÖVE 11.x. From the repo root, run:
```bash
love .
```