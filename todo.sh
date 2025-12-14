#!/usr/bin/env bash
# todo.sh - simple command-line To-Do List Manager
# Features:
#   - Multiple lists stored in ./todo_data/
#   - Add tasks with description, due date, priority, tags
#   - View tasks in a clean format
#   - Search tasks by keyword
#   - Mark tasks as complete (with recurrence)
#   - Delete tasks by ID
#
# Task format:
#   id|status|description|due|priority|tags|recurrence
#
# Usage examples:
#   ./todo.sh --list work --add "Finish report" --due 2024-12-01
set -euo pipefail

DATA_DIR="./todo_data"
DEFAULT_LIST="default"
mkdir -p "$DATA_DIR"

ensure_list() {
  local listfile="$DATA_DIR/$1.todo"
  [ ! -f "$listfile" ] && touch "$listfile"
  echo "$listfile"
}

next_id() {
  local file="$1"
  if [ ! -s "$file" ]; then echo 1; return; fi
  awk -F'|' 'BEGIN{m=0} {if($1>m)m=$1} END{print m+1}' "$file"
}
parse_date() {
  local d="$1"
  [[ "$d" =~ ^[0-9]{4}-[0-9]{2}-[0-9]{2}$ ]] && echo "$d" || echo ""
}

increment_date() {
  local date="$1"
  local recur="$2"
  case "$recur" in
    daily) date -I -d "$date + 1 day" ;;
    weekly) date -I -d "$date + 1 week" ;;
    monthly) date -I -d "$date + 1 month" ;;
    *) echo "" ;;
  esac
}

format_status() {
  [ "$1" -eq 1 ] && echo "Complete" || echo "Incomplete"
}

add_task() {
  local listfile="$1"
  local desc="$2"
  local due="$3"
  local pr="$4"
  local tags="$5"
  local recur="$6"

  local id
  id=$(next_id "$listfile")
  printf "%s|0|%s|%s|%s|%s|%s\n" \
    "$id" "$desc" "$due" "$pr" "$tags" "$recur" >> "$listfile"

  echo "Added task [$id]."
}

view_tasks() {
  local listfile="$1"
  if [ ! -s "$listfile" ]; then
    echo "(no tasks)"
    return
  fi

  awk -F'|' '{
    status = ($2==1 ? "Complete" : "Incomplete")
    printf("[%s] %s | %s | %s | %s | %s\n",
      $1, $3, $4, toupper($5), $6, status)
  }' "$listfile"
}
complete_task() {
  local listfile="$1"
  local id="$2"

  local line
  line=$(grep -E "^${id}\|" "$listfile" || true)
  [ -z "$line" ] && { echo "Task not found."; return; }

  awk -F'|' -v id="$id" 'BEGIN{OFS=FS} $1==id{$2=1} {print}' \
    "$listfile" > "$listfile.tmp"
  mv "$listfile.tmp" "$listfile"

  echo "Marked task $id as complete."
}

delete_task() {
  local listfile="$1"
  local id="$2"

  awk -F'|' -v id="$id" '$1 != id {print}' "$listfile" \
    > "$listfile.tmp"
  mv "$listfile.tmp" "$listfile"

  echo "Deleted task $id."
}

search_tasks() {
  local listfile="$1"
  local q="$2"

  grep -i "$q" "$listfile" | awk -F'|' '{
    status = ($2==1 ? "Complete" : "Incomplete")
    printf("[%s] %s | %s | %s | %s | %s\n",
      $1, $3, $4, $5, $6, status)
  }'
}
# ---------------------------
# Argument parsing
# ---------------------------

CMD=""
LIST_NAME="$DEFAULT_LIST"
DESC=""
DUE=""
PRIORITY=""
TAGS=""
RECUR="none"
SEARCH=""
TASK_ID=""

while (( "$#" )); do
  case "$1" in
    --list) LIST_NAME="$2"; shift 2 ;;
    --add) CMD="add"; DESC="$2"; shift 2 ;;
    --due) DUE="$2"; shift 2 ;;

    --priority) PRIORITY="$2"; shift 2 ;;
    --tags) TAGS="$2"; shift 2 ;;
    --recurrence) RECUR="$2"; shift 2 ;;
    --view) CMD="view"; shift ;;
    --complete) CMD="complete"; TASK_ID="$2"; shift 2 ;;
    --delete) CMD="delete"; TASK_ID="$2"; shift 2 ;;
    --search) CMD="search"; SEARCH="$2"; shift 2 ;;
    *) echo "Unknown argument: $1"; exit 1 ;;
  esac
done

LIST_FILE=$(ensure_list "$LIST_NAME")

case "$CMD" in
  add) add_task "$LIST_FILE" "$DESC" "$DUE" "$PRIORITY" "$TAGS" "$RECUR" ;;
  view) view_tasks "$LIST_FILE" ;;
  complete) complete_task "$LIST_FILE" "$TASK_ID" ;;
  delete) delete_task "$LIST_FILE" "$TASK_ID" ;;
  search) search_tasks "$LIST_FILE" "$SEARCH" ;;
  *) echo "No command provided." ;;
esac

