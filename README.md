# Trackpad Expression

A macOS menu-bar app that turns a trackpad (ideally a dedicated Magic Trackpad) into 1–4
vertical MIDI CC faders — expression, dynamics, vibrato — for orchestral virtual instruments.
It appears to your DAW as a MIDI input device called **Trackpad Expression**.

## Install

1. Download `TrackpadExpression-<version>.dmg` from the
   [Releases](../../releases) page, open it, and drag **Trackpad Expression** to **Applications**.
2. Open it once. macOS will say it "cannot verify" the app, because it isn't notarized by
   Apple (the developer doesn't have a paid Apple Developer account). Click **Done**.
3. Open **System Settings → Privacy & Security**, scroll down to the message about
   Trackpad Expression and click **Open Anyway**, then confirm.

You only have to do this once. Works on Apple Silicon and Intel Macs, macOS 14 or later.

<details>
<summary>Prefer Terminal?</summary>

```sh
xattr -dr com.apple.quarantine "/Applications/Trackpad Expression.app"
```
</details>

## Use

- **⌃⌥⌘E** enables, **⌃⌥⌘D** disables. Off by default; the trackpad works normally when off.
- While enabled, a click-through overlay shows each strip's value (no mouse-over needed).
- Strips run left → right across the trackpad. Each finger sticks to the strip it landed on.
- In your DAW, add "Trackpad Expression" as a MIDI input and select it on the instrument track.
  In **Fender Studio Pro / Studio One**, add it as a **Keyboard** (not Instrument or Control
  Surface), and set the instrument track's input to it or to *All Inputs*.

## Build

Requires the Xcode Command Line Tools (Swift 5.9+), macOS 14+.

```sh
scripts/create-signing-cert.sh       # once per machine: stable self-signed signing identity
scripts/build-app.sh                 # → build/Trackpad Expression.app (universal)
scripts/build-app.sh --install       # also copies it to /Applications
scripts/build-app.sh --dmg           # also creates build/TrackpadExpression-<version>.dmg
swift run touchtest --verbose        # original CLI feasibility test
```

The version number comes from `CFBundleShortVersionString` in `App/Info.plist`.

## Notes

- Uses Apple's private `MultitouchSupport.framework` to read raw touches without focus.
  A future macOS release could break it.
- "Block clicks, taps and scrolling" (optional) needs Accessibility permission. With ad-hoc
  signing, macOS forgets that permission on every rebuild; the self-signed certificate from
  `scripts/create-signing-cert.sh` keeps it stable.
- Trackpads are detected at launch; relaunch after connecting a new one.
