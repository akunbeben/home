# Privacy Mirror

Privacy Mirror runs as a menu bar app and creates an output window that mirrors the main display while omitting applications
with windows on configured AeroSpace workspaces. Share the **Privacy Mirror Output** window in Zoom, Meet,
or another conferencing app instead of sharing the physical display directly.

The output window stays on the main display behind normal windows. AeroSpace is configured to float
Privacy Mirror windows so the shareable output does not take over the tiling layout. The separate control
window may move with its AeroSpace workspace without affecting the share.

The local output window is parked below the desktop layer by default, so it keeps rendering for the shared
window without echoing through transparent windows on the desktop. Use the `PM` menu bar item to show or
park it again.

## Configuration

The app reads `~/.config/privacy-mirror/config.json` on launch. Press `Cmd+R` to reload it.

```json
{
  "excludedWorkspaces": ["4"],
  "placeholderStyle": "blur",
  "showsCursor": false,
  "captureFrameRate": 15
}
```

`placeholderStyle` accepts `blur` or `solid`.
`showsCursor` defaults to `false`; enable it only if the conferencing app does not draw its own cursor.
`captureFrameRate` defaults to `15` and accepts `1...60`; increase it only when the shared output needs smoother motion.

Privacy Mirror uses a fail-closed allow-list: new windows stay absent from the mirror until classified.
If an application has a window on an excluded workspace, every window from that application is omitted
so unmanaged dialogs and popovers cannot leak. A window from that application on a non-private workspace
will therefore also be omitted.

AeroSpace workspace changes, new windows, and the configured `Alt+Shift+number` move bindings blank the
output before reclassification. The move bindings use `privacy-mirror-move`, which waits for an
acknowledgment that the current stream is closed before asking AeroSpace to move the window. If
classification, the control socket, or the event subscription fails, the output remains
blank until `Cmd+R` succeeds. Moving a window with a direct external AeroSpace command that neither uses
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
