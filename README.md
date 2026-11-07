# Trackpad Expression

A macOS menu-bar app that turns a trackpad (ideally a dedicated Magic Trackpad) into 1–4
vertical MIDI CC faders — expression, dynamics, vibrato — for orchestral virtual instruments.
It appears to your DAW as a MIDI input device called **Trackpad Expression**.

## Use

- **⌃⌥⌘E** enables, **⌃⌥⌘D** disables. Off by default; the trackpad works normally when off.
- While enabled, a click-through overlay shows each strip's value (no mouse-over needed).
- Strips run left → right across the trackpad. Each finger sticks to the strip it landed on.
- In your DAW, add "Trackpad Expression" as a MIDI input and select it on the instrument track.

## Build

Requires the Xcode Command Line Tools (Swift 5.9+), macOS 14+.

```sh
scripts/build-app.sh            # → build/Trackpad Expression.app
scripts/build-app.sh --install  # also copies it to /Applications
swift run touchtest --verbose   # original CLI feasibility test
```

## Notes

- Uses Apple's private `MultitouchSupport.framework` to read raw touches without focus.
  A future macOS release could break it.
- "Block clicks, taps and scrolling" (optional) needs Accessibility permission. With ad-hoc
  signing, macOS forgets that permission on every rebuild — re-grant it after rebuilding.
- Trackpads are detected at launch; relaunch after connecting a new one.
