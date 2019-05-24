#!/usr/bin/env bash

platform="$(uname)"

save_cursor='\e[s'
restore_cursor='\e[u'
move_cursor_str='\e[1;%dH' # placeholder for offset

# TODO: help/usage text

# see https://www.iterm2.com/documentation-scripting.html
active_iterm_tab_id() {
  if [ "$platform" == "Darwin" ]
  then
    osascript <<EOF
    tell application "iTerm2"
      tell current session of current window
        id
      end tell
    end tell
EOF
  fi
}

# put a clock in the top right corner
# adapted from:
# - https://www.commandlinefu.com/commands/view/7916/put-a-console-clock-in-top-right-corner
# - https://stackoverflow.com/a/18773677/
#
# this updates the time every 5 seconds (since it only shows minute precision)
terminal_clock() {
  # this will ignore SIGINT (Ctrl-C) here, so sending that to the parent shell does not close this
  trap '' SIGINT

  # TODO: pass this to the script as an argument (or does the script get this automatically...)
  if [ -n "$ITERM_SESSION_ID" ] && [[ "$ITERM_SESSION_ID" =~ :([0-9A-F-]*) ]]
  then
    iterm_id="${BASH_REMATCH[1]}"
  fi
  echo "iTerm ID: $iterm_id"

  # TODO: this will have to be an argument
  shell_pid="$$"
  echo "shell PID: $shell_pid"
  # TODO: and this should exit when that PID goes away (session is closed)

  # update every 5 seconds (knowing the time all the time is not that important)
  # TODO: make this value configurable
  while sleep 5
  do
    # if there is a foreground process running, don't update the clock
    # (adapted from https://unix.stackexchange.com/a/273785)
    #  state shows the state, where '+' means running in the foreground
    #  ppid shows the parent PID (to grep for the pid of the shell)
    #  comm shows the command (but not the arguments, so this doesn't match the grep)
    # this greps for the shell PID, filters out the bash process running the clock, and looks for any FG process
    fg_proc="$(ps -e -o state= -o ppid= -o comm= | grep -Fw $shell_pid | grep -v "bash" | grep -F '+')"

    # and only update the clock if this iTerm tab is the active one

    if [ -z "$fg_proc" ] && [[ -z "$iterm_id" || "$iterm_id" == "$(active_iterm_tab_id)" ]]
    then
      # need to do these calculations every time
      # TODO: calculate the length of the curr_datetime string, and use that here instead of a magic number
      # TODO: also, if this is wider than the terminal width, don't display it
      col_offset="$(( $(tput cols)-22 ))"
      curr_datetime="$(date +'%a %b %d, %H:%M %Z')" # formatted like "Mon May 20, 14:36 PDT"
      move_cursor="$(printf "$move_cursor_str" "$col_offset")"
      # do the positioning and output all in one go, outputting to stderr
      # (with a space before and after the date for readability)
      echo -en "${save_cursor}${move_cursor} ${curr_datetime} ${restore_cursor}" >&2
    fi
  done
}
