# Week at a Glance — Übersicht Widget

A desktop calendar widget for macOS that shows the current 7-day window of events from Apple Calendar (Google Cal + Barnes & Noble Dayforce shifts), refreshed hourly via a launchd service.

## Files

| File | Purpose |
|------|---------|
| `widget.jsx` | Übersicht widget — copy to Übersicht widgets folder |
| `generate.sh` | Fetches events from Apple Calendar → writes `week-calendar.json` |
| `week-calendar.json` | Data file read by the widget (auto-generated, do not edit) |
| `com.tony.calendar-widget.plist` | launchd job definition (hourly schedule) |
| `service.sh` | Service management script (enable/disable/start/stop/status) |

## Setup

### 1. Test the data generator
```bash
./service.sh run
```
Runs `generate.sh` in the foreground. Should complete in a few seconds and write `week-calendar.json`.

### 2. Install the widget
```bash
cp widget.jsx ~/Library/Application\ Support/Übersicht/widgets/week-calendar.jsx
```
> **Note:** Use `cp`, not `ln -s`. Übersicht cannot follow symlinks across volumes.

Then right-click the Übersicht menubar icon → **Refresh All Widgets**.

### 3. Enable the hourly service
```bash
./service.sh enable
```
Installs the launchd plist to `~/Library/LaunchAgents/` and starts the job. It runs immediately on load, then every hour.

## Service Management

```bash
./service.sh status    # Show load state, PID, last exit code, data file age
./service.sh start     # Trigger an immediate refresh
./service.sh stop      # Stop a currently-running job
./service.sh restart   # Stop then start
./service.sh disable   # Remove from LaunchAgents and stop
./service.sh logs      # Tail the log file
./service.sh run       # Run generate.sh in the foreground (for testing)
```

## How It Works

1. `generate.sh` uses AppleScript to query two Apple Calendar sources:
   - **`anthonyhoffman@gmail.com`** — synced Google Calendar events
   - **`Dayforce_barnesnoble`** — Barnes & Noble work shifts
2. Events for the current 7-day window are parsed and written to `week-calendar.json`.
3. The Übersicht widget reads the JSON via `cat` every 5 minutes and renders the week view.
4. launchd runs `generate.sh` every hour to keep the data fresh.

## Updating the Widget

If you edit `widget.jsx`, copy it to the Übersicht folder again:
```bash
cp widget.jsx ~/Library/Application\ Support/Übersicht/widgets/week-calendar.jsx
```
Then refresh Übersicht.

## Logs

```
logs/generate.log       # Script output (timestamps + event counts)
logs/launchd.log        # stdout from launchd runs
logs/launchd-error.log  # stderr from launchd runs
```

## Adjusting Position

Edit the `className` export at the top of `widget.jsx`:
```js
export const className = `
  top: 20px;
  left: 20px;   /* change to right: 20px to move to the right side */
  width: 340px; /* adjust width as needed */
  ...
`;
```
Then copy and refresh.
