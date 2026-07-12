# Privacy Mirror

Privacy Mirror creates a background output window that mirrors the main display while omitting applications
with windows on configured AeroSpace workspaces. Share the **Privacy Mirror Output** window in Zoom, Meet,
or another conferencing app instead of sharing the physical display directly.

The output window stays on the main display behind normal windows and is deliberately invisible to
AeroSpace's accessibility tree, so switching workspaces does not interrupt the shared output. The separate
control window may move with its AeroSpace workspace without affecting the share.

## Configuration

The app reads `~/.config/privacy-mirror/config.json` on launch. Press `Cmd+R` to reload it.

```json
{
  "excludedWorkspaces": ["4"],
  "placeholderStyle": "blur"
}
```

`placeholderStyle` accepts `blur` or `solid`.

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

Allow Privacy Mirror in **System Settings → Privacy & Security → Screen & System Audio Recording**, then
relaunch it. Home Manager installs the app under `~/Applications/Home Manager Apps`.

The Nix package is ad-hoc signed. Changing and rebuilding the application changes its code identity, so
macOS may require Screen Recording permission again after an application update. JSON-only configuration
changes do not rebuild the app or affect the permission.

## Development

Run the core tests and compile the app with:

```sh
swift test --package-path apps/privacy-mirror
```
