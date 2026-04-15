# Nuzi Vehicles

Boat nerd math, but packaged in a way that does not require a clipboard and a headache.

`Nuzi Vehicles` keeps your movement readouts where you can use them:

- speed HUD for live travel speed
- nautical compass window with heading and travel direction
- profile switching for different vehicle models
- separate toggle, main, speed, and compass windows
- persistent window positions through reloads and relogs

## Install

1. Install via Addon Manager
2. Make sure its enabled in game.

Saved data lives in `nuzi-vehicles/.data` so your positions and selected profile survive updates.

## Quick Start

1. Open the main window from the toggle button.
2. Switch to the vehicle profile you want.
3. Show the `Speed HUD` if you want live speed telemetry.
4. Show the `Compass` if you want heading guidance.
5. Drag the windows where you want them.

Because if you are going to overthink boat movement, you may as well do it with nice numbers.

## How To

### Main Window

The main window lets you:

- cycle previous or next vehicle profile
- show or hide the speed HUD
- show or hide the compass window

### Speed HUD

The speed HUD is the compact readout for live movement speed.

Use it when you only care about how fast the vehicle is actually moving.

### Compass

The compass window shows:

- current heading
- travel direction
- arrow guidance
- axis and efficiency readouts

That makes it the better tool when you care about heading quality instead of just raw speed.

## Notes

- Main window, speed HUD, compass window, and toggle button all save their positions.
- The addon uses profiles so the guidance stays matched to the selected vehicle model instead of pretending every boat handles the same.
- If a window seems out of place after a UI reload, the saved positions should be re-applied automatically.

## Version

Current version: `1.0.8`
