#!/usr/bin/env bash

# put a clock in the top right corner
# TODO: split this off into it's own repo
# (adapted from https://www.commandlinefu.com/commands/view/7916/put-a-console-clock-in-top-right-corner and https://stackoverflow.com/a/18773677/)
# this updates the time every 5 seconds (since it only shows minute precision)
terminal_clock() {
  # this will ignore SIGINT (Ctrl-C) here, so sending that to the parent shell does not close this
  trap '' SIGINT

  shell_pid="$$"
  echo "shell PID: $shell_pid"
  save_cursor='\e[s'
  restore_cursor='\e[u'
  move_cursor_str='\e[1;%dH' # placeholder for offset
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
    if [ -z "$fg_proc" ]
    then
      # need to do these calculations every time
      # TODO: calculate the length of the curr_datetime string, and use that here instead of a magic number
      col_offset="$(( $(tput cols)-22 ))"
      curr_datetime="$(date +'%a %b %d, %H:%M %Z')" # formatted like "Mon May 20, 14:36 PDT"
      move_cursor="$(printf "$move_cursor_str" "$col_offset")"
      # do the positioning and output all in one go, outputting to stderr
      # (with a space before and after the date for readability)
      echo -en "${save_cursor}${move_cursor} ${curr_datetime} ${restore_cursor}" >&2
    fi
  done
}

