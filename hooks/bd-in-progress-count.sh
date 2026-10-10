#!/usr/bin/env bash
# Sourced (not executed) by the work-state-anchor and stop-gate hooks, Claude and
# Codex variants. Defines bd_in_progress_count, which prints the number of
# in_progress beads issues as seen from $PWD, or nothing when unknown.
#
# `bd list` opens the embedded Dolt database on every call (~600-700ms), and these
# hooks run on every prompt and every turn end. The count is cached against the
# database's own state: the Dolt manifest (root hash) plus the chunk journal's
# size. Every bd write appends to the journal and moves the root; reads touch file
# mtimes but change neither, so mtimes are deliberately not part of the key.
# Which database bd uses comes from `bd where`, cached per directory. Anything that
# is not a plain embedded-Dolt layout (server mode, BEADS_DB, no journal) skips the
# cache and calls bd directly.
#
# Requires bd and jq on PATH; callers check both before calling.

_bdc_query() {
  bd list --status in_progress --json 2>/dev/null | jq 'length' 2>/dev/null || printf ''
}

# Size in bytes of a file: GNU stat first, BSD stat as the fallback.
_bdc_size() {
  stat -c '%s' "$1" 2>/dev/null || stat -f '%z' "$1" 2>/dev/null
}

# State key for the embedded database under a .beads directory, or failure when
# the layout is not one the key is known to track.
_bdc_db_key() {
  local beads_dir="$1" db noms size sum
  [ -f "$beads_dir/metadata.json" ] || return 1
  db=$(jq -r 'if .dolt_mode == "embedded" then (.dolt_database // empty) else empty end' \
    "$beads_dir/metadata.json" 2>/dev/null) || return 1
  [ -n "$db" ] || return 1
  noms="$beads_dir/embeddeddolt/$db/.dolt/noms"
  [ -f "$noms/manifest" ] && [ -f "$noms/vvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvv" ] || return 1
  sum=$(cksum < "$noms/manifest") || return 1
  size=$(_bdc_size "$noms/vvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvv")
  [ -n "$size" ] || return 1
  printf '%s|%s' "$sum" "$size"
}

bd_in_progress_count() {
  if [ -n "${BEADS_DB:-}" ]; then
    _bdc_query
    return 0
  fi

  local loc_key="${PWD}|${BEADS_DIR:-}" cache base
  base="${TMPDIR:-/tmp}"
  cache="${base%/}/superpowers-bd-in-progress-${UID:-0}${PWD//\//_}"

  # Cache layout, one value per line: location key, .beads dir, db key, count.
  local c_loc="" c_dir="" c_db="" c_count=""
  if [ -f "$cache" ]; then
    { IFS= read -r c_loc; IFS= read -r c_dir; IFS= read -r c_db; IFS= read -r c_count; } \
      < "$cache" 2>/dev/null || true
  fi

  local beads_dir=""
  # A cached location is dropped if it vanished or a .beads appeared right here.
  if [ "$c_loc" = "$loc_key" ] && [ -n "$c_dir" ] && [ -d "$c_dir" ] \
    && { [ ! -d "$PWD/.beads" ] || [ "$PWD/.beads" = "$c_dir" ]; }; then
    beads_dir="$c_dir"
  else
    beads_dir=$(bd where --json 2>/dev/null | jq -r '.path // empty' 2>/dev/null) || beads_dir=""
  fi

  local db_key
  if [ -z "$beads_dir" ] || ! db_key=$(_bdc_db_key "$beads_dir"); then
    _bdc_query
    return 0
  fi

  if [ "$c_loc" = "$loc_key" ] && [ "$c_dir" = "$beads_dir" ] && [ "$c_db" = "$db_key" ] \
    && [ -n "$c_count" ]; then
    printf '%s' "$c_count"
    return 0
  fi

  # db_key was read before the query, so a write racing the query leaves a key
  # that no longer matches the database and the next call queries again.
  local count tmp
  count=$(_bdc_query)
  case "$count" in
    '' | *[!0-9]*) printf '%s' "$count"; return 0 ;;
  esac
  tmp="${cache}.$$"
  if printf '%s\n%s\n%s\n%s\n' "$loc_key" "$beads_dir" "$db_key" "$count" > "$tmp" 2>/dev/null; then
    mv -f "$tmp" "$cache" 2>/dev/null || rm -f "$tmp"
  fi
  printf '%s' "$count"
}
