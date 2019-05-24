#!/usr/bin/env bash

# put a clock in the top right corner
# adapted from:
# - https://www.commandlinefu.com/commands/view/7916/put-a-console-clock-in-top-right-corner
# - https://stackoverflow.com/a/18773677/
# TODO: more here?


# TODO: help/usage text

# this ignores SIGINT (Ctrl-C), so using that in the parent shell does not close this
trap '' SIGINT

platform="$(uname)"

# constants
save_cursor='\e[s'
restore_cursor='\e[u'
move_cursor_str='\e[1;%dH' # placeholder for offset


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

# arguments
shell_pid="${1:?No shell PID provided}"

# the script inherits this env var
if [ -n "$ITERM_SESSION_ID" ] && [[ "$ITERM_SESSION_ID" =~ :([0-9A-F-]*) ]]
then
  iterm_id="${BASH_REMATCH[1]}"
fi
echo "iTerm ID: $iterm_id"

echo "shell PID: $shell_pid"

# update every 5 seconds (knowing the time all the time is not that important)
# TODO: make this value configurable
while sleep 5
do
  # if the parent shell has exited, then this should exit as well
  # otherwise this will continue running when the session exits, because it has open terminal file handles
  # (see https://stackoverflow.com/a/8123399)
  if ! kill -0 $shell_pid 2>/dev/null; then exit 0; fi
  #
  # $ ps -e -o ppid= -o pid= -o user= -o command= | grep "sleep 1"
  # 44171 20066 mikrostew        sleep 1
  # 45203 20068 mikrostew        sleep 1
  # 89572 20069 mikrostew        sleep 1
  # 47244 20071 mikrostew        sleep 1
  # 86790 20072 mikrostew        sleep 1
  # 48661 20083 mikrostew        sleep 1
  # 63464 20084 mikrostew        sleep 1
  # 85330 20090 mikrostew        sleep 1
  #  5968 20109 mikrostew        sleep 1
  # 13536 20110 mikrostew        sleep 1
  # 14535 20111 mikrostew        sleep 1
  # 92865 20122 mikrostew        sleep 1
  # 84829 20123 mikrostew        sleep 1
  # 84788 20125 mikrostew        grep --color=auto sleep 1

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
