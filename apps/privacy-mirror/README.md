# Privacy Mirror

Privacy Mirror runs as a menu bar app and creates an output window that can mirror the main display while
omitting applications with windows on configured AeroSpace workspaces. Share the **Privacy Mirror Output**
window in Zoom, Meet, or another conferencing app instead of sharing the physical display directly.

The output window stays on the main display behind normal windows. AeroSpace is configured to float
Privacy Mirror windows so the shareable output does not take over the tiling layout. The separate control
window may move with its AeroSpace workspace without affecting the share.

On launch, Privacy Mirror shows the output window without starting ScreenCaptureKit, so normal desktop
work stays unaffected while the app is standing by. After sharing **Privacy Mirror Output**, park it from
the `PM` menu bar item or the keyboard shortcut. Parking starts mirroring and moves the local output below
the desktop layer so it keeps rendering for the share without echoing through transparent windows on the
desktop. Showing the output window again stops mirroring and returns the app to standby.

## Configuration

The app reads `~/.config/privacy-mirror/config.json` on launch. Use the configured shortcut or the `PM`
menu to reload it.

```json
{
  "excludedWorkspaces": ["4"],
  "placeholderStyle": "blur",
  "showsCursor": false,
  "captureFrameRate": 10,
  "captureMaxWidth": 1920,
  "shortcuts": {
    "reloadConfiguration": "option+shift+r",
    "showOutput": "option+shift+s",
    "parkOutput": "option+shift+p"
  }
}
```

`placeholderStyle` accepts `blur` or `solid`.
`showsCursor` defaults to `false`; enable it only if the conferencing app does not draw its own cursor.
`captureFrameRate` defaults to `10` and accepts `1...60`; increase it only when the shared output needs smoother motion.
`captureMaxWidth` defaults to `1920` and caps the ScreenCaptureKit stream width to reduce long-running
CPU/GPU load.
Shortcut strings support combinations such as `option+shift+p`, `cmd+shift+s`, and `ctrl+option+r`.

Privacy Mirror uses a fail-closed allow-list: new windows stay absent from the mirror until classified.
If an application has a window on an excluded workspace, every window from that application is omitted
so unmanaged dialogs and popovers cannot leak. A window from that application on a non-private workspace
will therefore also be omitted.

AeroSpace workspace changes, new windows, and the configured `Alt+Shift+number` move bindings blank the
output before reclassification. The move bindings use `privacy-mirror-move`, which waits for an
acknowledgment that the current stream is closed before asking AeroSpace to move the window. If
classification, the control socket, or the event subscription fails, the output remains
blank until reload succeeds. Moving a window with a direct external AeroSpace command that neither uses
those bindings nor changes the focused workspace cannot be observed before AeroSpace changes state; avoid
that workflow during a share.

The output is a ScreenCaptureKit composition of the current shareable-window catalog, including desktop
windows exposed by macOS. A system surface that ScreenCaptureKit does not expose may differ from a raw
physical-display capture.

## First launch

Home Manager creates a local code-signing identity when needed and installs the signed app copy at
`~/Applications/Privacy Mirror.app`.

Allow Privacy Mirror in **System Settings → Privacy & Security → Screen & System Audio Recording**, then
relaunch it. The local signing identity keeps Privacy Mirror's code identity stable across rebuilds, so
macOS should not ask for Screen Recording permission again unless the signing identity is deleted or reset.

## Development

Run the core tests and compile the app with:

```sh
swift test --package-path apps/privacy-mirror
```
