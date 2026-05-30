#!/bin/bash
# generate.sh — Fetch Apple Calendar events for the current 7-day window
# and write week-calendar.json for the Übersicht widget.
#
# Reads from ALL Apple Calendar calendars; marks Dayforce_barnesnoble events
# with isDayforce: true. Google Calendar events sync automatically via macOS.
#
# Output: /Volumes/External_Projects/calendar_widget/week-calendar.json

set -euo pipefail

WIDGET_DIR="/Volumes/External_Projects/calendar_widget"

OUTPUT="$WIDGET_DIR/week-calendar.json"
LOG="$WIDGET_DIR/logs/generate.log"
mkdir -p "$WIDGET_DIR/logs"

log() { echo "[$(date '+%Y-%m-%d %H:%M:%S')] $*" >> "$LOG"; }

log "Starting calendar data refresh..."

# ── Step 1: Pull events from Apple Calendar via AppleScript ─────────────────
# Launch Calendar first so it's ready — avoids timeout if the app was closed
osascript -e 'tell application "Calendar" to launch' 2>/dev/null || true
sleep 1

RAW=$(osascript <<'APPLESCRIPT'
-- Target only the two calendars we care about to keep this fast
set TARGET_CALS to {"anthonyhoffman@gmail.com", "Dayforce_barnesnoble"}

tell application "Calendar"
  set now to current date
  set startDate to now
  set hours of startDate to 0
  set minutes of startDate to 0
  set seconds of startDate to 0
  set endDate to startDate + (6 * days)
  set hours of endDate to 23
  set minutes of endDate to 59
  set seconds of endDate to 59

  set output to ""
  repeat with calName in TARGET_CALS
    try
      set cal to calendar calName
      set isDFstr to "false"
      if calName is "Dayforce_barnesnoble" then set isDFstr to "true"
      set allEvents to (every event of cal whose start date >= startDate and start date <= endDate)
      repeat with e in allEvents
        set eTitle to summary of e
        set eStart to start date of e as string
        set eEnd to end date of e as string
        set isAllDay to "false"
        if (allday event of e) then set isAllDay to "true"
        set output to output & isDFstr & "|||" & isAllDay & "|||" & eTitle & "|||" & eStart & "|||" & eEnd & linefeed
      end repeat
    end try
  end repeat
  return output
end tell
APPLESCRIPT
)

if [[ -z "$RAW" ]]; then
  log "No events returned from Calendar — writing empty JSON."
  echo '{"events":[],"updated":"'"$(date '+%B %-d, %Y')"'"}' > "$OUTPUT"
  exit 0
fi

# ── Step 2: Parse AppleScript output → JSON via Python ──────────────────────
python3 - "$OUTPUT" <<PYEOF
import sys, json, re
from datetime import datetime, timedelta, timezone

output_path = sys.argv[1]

raw = """$RAW"""

def parse_as_date(s):
    """Convert AppleScript date string to ISO-8601 with America/Los_Angeles offset.
       AppleScript format: 'Friday, May 29, 2026 at 3:30:00 PM'
    """
    s = s.strip()
    # Remove day-of-week prefix
    s = re.sub(r'^[A-Za-z]+, ', '', s)
    try:
        dt = datetime.strptime(s, '%B %d, %Y at %I:%M:%S %p')
    except ValueError:
        dt = datetime.strptime(s, '%B %d, %Y at %I:%M:%S %p')

    # Determine PDT vs PST (rough: Mar–Nov = PDT = -07:00, else PST = -08:00)
    month = dt.month
    offset = '-07:00' if 3 <= month <= 11 else '-08:00'
    return dt.strftime('%Y-%m-%dT%H:%M:%S') + offset

def parse_as_date_only(s):
    """For all-day events, return YYYY-MM-DD."""
    s = s.strip()
    s = re.sub(r'^[A-Za-z]+, ', '', s)
    try:
        dt = datetime.strptime(s, '%B %d, %Y at %I:%M:%S %p')
        return dt.strftime('%Y-%m-%d')
    except Exception:
        return None

seen = set()
events = []

for line in raw.strip().splitlines():
    line = line.strip()
    if not line:
        continue
    parts = line.split('|||')
    if len(parts) != 5:
        continue

    is_dayforce = parts[0].strip() == 'true'
    is_all_day  = parts[1].strip() == 'true'
    title       = parts[2].strip()
    start_raw   = parts[3].strip()
    end_raw     = parts[4].strip()

    # Deduplicate by (title, start)
    key = (title, start_raw)
    if key in seen:
        continue
    seen.add(key)

    # Strip common Google Calendar "Ticket: " prefixes
    if title.startswith('Ticket: '):
        title = title[8:]

    if is_all_day:
        start_str = parse_as_date_only(start_raw)
        end_str   = parse_as_date_only(end_raw)
        if not start_str:
            continue
        events.append({
            'title': title,
            'start': start_str,
            'end':   end_str or start_str,
            'allDay': True,
            'isDayforce': is_dayforce,
        })
    else:
        try:
            start_str = parse_as_date(start_raw)
            end_str   = parse_as_date(end_raw)
        except Exception:
            continue
        events.append({
            'title': title,
            'start': start_str,
            'end':   end_str,
            'allDay': False,
            'isDayforce': is_dayforce,
        })

# Sort: all-day first, then by start time
events.sort(key=lambda e: (not e['allDay'], e['start']))

today = datetime.now()
payload = {
    'events': events,
    'updated': today.strftime('%B %-d, %Y'),
}

with open(output_path, 'w') as f:
    json.dump(payload, f, indent=2)

print(f"Wrote {len(events)} events to {output_path}")
PYEOF

log "Done. $(python3 -c "import json; d=json.load(open('$OUTPUT')); print(len(d['events']),'events written.')")"
