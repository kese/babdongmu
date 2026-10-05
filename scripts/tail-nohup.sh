#!/bin/sh
# Follow nohup.out with auto-reopen and keep cursor at the end for easier monitoring.
# Usage: ./scripts/tail-nohup.sh [/path/to/nohup.out]

LOG_FILE=${1:-nohup.out}

if [ ! -f "$LOG_FILE" ]; then
  echo "Log file not found: $LOG_FILE" >&2
  exit 1
fi

# tail -F keeps following even when the file is rotated or recreated.
# -n 200 shows recent context so you don't have to scroll back manually.
exec tail -n 200 -F "$LOG_FILE"
