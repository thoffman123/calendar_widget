# Week at a Glance — Übersicht Widget

A desktop calendar widget for macOS that shows the current 7-day window of events from Apple Calendar (including synced Google Calendar events and Barnes & Noble Dayforce shifts), refreshed hourly via a launchd service. Click an event to open it in Calendar.app.

## Files

| File | Purpose |
|------|---------|
| `widget.jsx` | Übersicht widget — copy to Übersicht widgets folder |
| `generate.sh` | Fetches events from Apple Calendar → writes `week-calendar.json` |
| `com.tony.calendar-widget.plist` | launchd job definition (hourly schedule) |
| `service.sh` | Service management script (enable/disable/start/stop/status) |

## Setup

### 1. Test the data generator
```bash
./service.sh run
```
Runs `generate.sh` in the foreground and writes `week-calendar.json`. Calendar's AppleScript interface is slow, so this can take a few minutes.

### 2. Install the widget
```bash
cp widget.jsx ~/Library/Application\ Support/Übersicht/widgets/week-calendar.jsx
```
> **Note:** Use `cp`, not `ln -s`. Übersicht cannot follow symlinks across volumes.

Then right-click the Übersicht menubar icon → **Refresh All Widgets**.

#### Enable clicking events
Clicking an event opens it in Calendar.app. For clicks to reach the widget:

- Put the widget on the **foreground layer**: Übersicht menubar icon → **week-calendar** → turn off **Background**. A background-layer widget sits behind the desktop, so the desktop swallows clicks and nothing happens. (The setting is stored as `"inBackground"` in `~/Library/Application Support/tracesOf.Uebersicht/WidgetSettings.json`.)
- Make sure widget interaction is enabled in Übersicht's preferences.
- On the first click, macOS asks to let Übersicht control Calendar — click **Allow**.

One-off events open with the event selected. Recurring events (and any event that can't be found) open Calendar's day view on the clicked date.

### 3. Enable the hourly service
```bash
./service.sh enable
```
This:
- copies `generate.sh` to `~/Library/Scripts/com.tony.calendar-widget/` (macOS blocks launchd agents from running scripts on external volumes),
- installs the launchd plist to `~/Library/LaunchAgents/`,
- copies `widget.jsx` into the Übersicht widgets folder,
- starts the job. It runs immediately on load, then every hour.

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

1. `generate.sh` uses AppleScript to read events from **every** Apple Calendar calendar, skipping holiday, birthday and Siri Suggestions calendars. Events from **`Dayforce_barnesnoble`** (Barnes & Noble work shifts) are tagged and shown in orange with a B&N badge.
2. Events for the current 7-day window are written to `~/Library/Application Support/com.tony.calendar-widget/week-calendar.json`, with times in `America/Los_Angeles` (correct PDT/PST offset per date), plus each event's uid and calendar name for click-to-open.
3. The Übersicht widget reads the JSON via `cat` every 5 minutes and renders the week view.
4. launchd runs the installed copy of `generate.sh` every hour to keep the data fresh.

## Updating the Widget

If you edit `widget.jsx`, copy it to the Übersicht folder again:
```bash
cp widget.jsx ~/Library/Application\ Support/Übersicht/widgets/week-calendar.jsx
```
Then refresh Übersicht.

If you edit `generate.sh`, reinstall it so the hourly job picks it up (or run `./service.sh enable` again):
```bash
cp generate.sh ~/Library/Scripts/com.tony.calendar-widget/generate.sh
```

## Logs

In `~/Library/Logs/com.tony.calendar-widget/`:
```
generate.log       # Script output (timestamps + event counts)
launchd.log        # stdout from launchd runs
launchd-error.log  # stderr from launchd runs, e.g. "AppleEvent timed out" if Calendar hangs
```
If refreshes keep timing out, quit and reopen Calendar.

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
