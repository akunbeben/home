# Work-Hours Display Awake Design

## Goal

Keep the Mac display awake from 08:00 until 17:00 local time, Monday through
Friday, on both battery and external power. Outside that window, turn the
display off after two minutes of inactivity.

## Design

Set the system-wide `pmset` display-sleep timeout to two minutes from a
nix-darwin activation script. Add one Home Manager launch agent that starts at
08:00 on weekdays and runs at agent load.

The agent script checks the local weekday and time. It exits immediately
outside the work-hours window. During the window, it calculates the seconds
remaining until 17:00 and executes `caffeinate -d -t <seconds>`. Calculating the
remaining duration prevents a delayed launch after sleep, login, or rebuild
from keeping the display awake past 17:00.

## Scope and Safety

- Apply the same behavior on battery and external power.
- Use local system time and do not add holiday-calendar handling.
- Prevent idle display sleep only; do not prevent explicit locking or closing
  the laptop lid.
- Follow the repository's existing Home Manager launch-agent pattern.
- Do not modify unrelated configuration.

## Verification

- Evaluate the flake with `nix flake check`.
- Inspect the evaluated launch-agent schedule and command.
- Check the script's behavior for weekday times before, during, and after the
  work-hours window, plus a weekend time.
