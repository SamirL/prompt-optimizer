#!/bin/bash
set -euo pipefail

# Read hook input from stdin
HOOK_INPUT=$(cat)

# Extract session ID
SESSION_ID=$(echo "$HOOK_INPUT" | jq -r '.session_id // ""')
if [[ -z "$SESSION_ID" ]]; then
  exit 0
fi

# Check if we already asked this session
STATE_DIR="/tmp/claude-kanban"
STATE_FILE="$STATE_DIR/$SESSION_ID"
if [[ -f "$STATE_FILE" ]]; then
  exit 0
fi

# Check if .kanban.json exists in the current working directory
if [[ ! -f ".kanban.json" ]]; then
  exit 0
fi

# Check if there are tasks in the "doing" column
DOING_COUNT=$(jq '.doing | length' .kanban.json 2>/dev/null || echo "0")
if [[ "$DOING_COUNT" -eq 0 ]]; then
  exit 0
fi

# Get the titles of tasks in Doing
DOING_TASKS=$(jq -r '.doing[] | "#\(.id) \(.title)"' .kanban.json 2>/dev/null | head -5)

# Mark as asked for this session
mkdir -p "$STATE_DIR"
touch "$STATE_FILE"

# Block and remind about in-progress tasks
jq -n \
  --arg count "$DOING_COUNT" \
  --arg tasks "$DOING_TASKS" \
  --arg reason "You have $DOING_COUNT task(s) still in the Doing column on the Kanban board:
$DOING_TASKS

Before ending the session, please update their status — move completed tasks to Done, or leave a note if they're still in progress. You can also ask the user if they want to update the board. Use /kanban to see the full board." \
  '{"decision": "block", "reason": $reason}'

exit 0
