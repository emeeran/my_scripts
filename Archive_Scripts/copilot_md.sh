#!/bin/bash

# A script to export GitHub Copilot chat history for a specific day to a Markdown file.
# Usage: ./export-copilot-chat.sh YYYY-MM-DD
# Example: ./export-copilot-chat.sh 2025-07-17

# --- Configuration ---
# The database path has been updated to your specific location.
DB_PATH="/home/em/.config/Code/User/globalStorage/github.copilot-chat/chat.db"

# "/home/em/.config/Code/User/globalStorage/github.copilot-chat/chat.db"
# --- Script Logic ---

# 1. Validate input and dependencies
if ! command -v sqlite3 &> /dev/null; then
    echo "Error: sqlite3 is not installed. Please install it to continue." >&2
    exit 1
fi

if ! command -v jq &> /dev/null; then
    echo "Error: jq is not installed. Please install it to continue." >&2
    exit 1
fi

if [[ -z "$1" ]]; then
    echo "Usage: $0 YYYY-MM-DD" >&2
    exit 1
fi

DATE_INPUT="$1"
OUTPUT_MD="copilot-chat-${DATE_INPUT}.md"
OUTPUT_JSON="copilot-chat-${DATE_INPUT}.json"

# 2. Check if the database file exists
if [[ ! -f "$DB_PATH" ]]; then
    echo "Error: GitHub Copilot chat database not found at:" >&2
    echo "$DB_PATH" >&2
    echo "Please verify the path." >&2
    exit 1
fi

# 3. Convert target date to start/end epoch milliseconds for the query
# Using date command compatible with both GNU and macOS
if [[ "$(uname)" == "Darwin" ]]; then # macOS
    START_TS=$(date -j -f "%Y-%m-%d %H:%M:%S" "$DATE_INPUT 00:00:00" "+%s")000
    END_TS=$(date -j -f "%Y-%m-%d %H:%M:%S" "$DATE_INPUT 23:59:59" "+%s")999
else # GNU/Linux
    START_TS=$(date -d "$DATE_INPUT 00:00:00" +%s)000
    END_TS=$(date -d "$DATE_INPUT 23:59:59" +%s)999
fi

echo "🔍 Searching for chats on $DATE_INPUT..."

# 4. Query SQLite DB, get all sessions, and filter by date with jq
# The data is stored as a JSON string in a key-value table.
# We extract the string, then use jq to parse and filter it.
RAW_JSON_SESSIONS=$(sqlite3 "$DB_PATH" \
    "SELECT value FROM kvstore WHERE key = 'interactive-sessions-v0'" | \
    jq --argjson start_ts "$START_TS" --argjson end_ts "$END_TS" \
    'fromjson | map(select(.createdAt >= $start_ts and .createdAt <= $end_ts))')

# Check if any sessions were found
if [[ "$(echo "$RAW_JSON_SESSIONS" | jq 'length')" -eq 0 ]]; then
    echo "No chat sessions found for $DATE_INPUT."
    exit 0
fi

# 5. Export filtered sessions to a JSON file
echo "$RAW_JSON_SESSIONS" > "$OUTPUT_JSON"
echo "✅ Raw chat data exported to $OUTPUT_JSON"

# 6. Convert the filtered JSON to Markdown
echo "# GitHub Copilot Chat - $DATE_INPUT" > "$OUTPUT_MD"
echo "" >> "$OUTPUT_MD"

echo "$RAW_JSON_SESSIONS" | jq -r '
    .[] | 
    "# Chat Session started at " + (.createdAt / 1000 | strftime("%Y-%m-%d %H:%M:%S")) + "\n---\n" + (
        .history | .[] | 
        "### " + (if .role == "user" then "🧑 User" else "🤖 Bot" end) + 
        "\n\n" + .content + "\n"
    )
' >> "$OUTPUT_MD"

echo "✅ Chat content successfully exported to $OUTPUT_MD"
