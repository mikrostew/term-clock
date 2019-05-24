#!/usr/bin/env bash

# Display the time and date in the top right corner of the terminal
# adapted from:
# - https://www.commandlinefu.com/commands/view/7916/put-a-console-clock-in-top-right-corner
# - https://stackoverflow.com/a/18773677/


usage() {
  cat >&2 <<'END_USAGE'
term-clock: Display the time and date in the top right corner of the terminal

USAGE:
    term-clock [FLAGS] <shell_pid> [OPTIONS]

FLAGS:
    -h, --help                  Prints this help information
    -v, --version               Prints version information

OPTIONS:
    -f, --format <date_fmt>     Format to use for the `date` command.
                                By default this runs plain `date`, where the output
                                format looks like "Thu May 23 23:54:55 PDT 2019".
                                Run `date --help` to see the formatting options.
    -i, --interval <seconds>    The number of seconds between clock updates.
                                (default is 5 seconds)
END_USAGE
}

TC_VERSION="0.1.0"

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

# shell PID is required
shell_pid="${1:?No shell PID provided}"
shift

# defaults
date_fmt="" # use whatever the default is for `date`
update_int=5

# parse any optional args
while [ $# -gt 0 ]
do
  arg="$1"

  case "$arg" in
    -h|--help)
      usage
      exit 0
      ;;
    -v|--version)
      echo $TC_VERSION
      exit 0
      ;;
    -f|--format)
      shift # shift off the argument
      date_fmt="+$1"
      shift # shift off the value
      ;;
    -i|--interval)
      shift # shift off the argument
      update_int="$1"
      shift # shift off the value
      ;;
    *)
      echo "term-clock: unknown option: '$arg'" >&2
      exit 1
      ;;
  esac
done

# the script inherits this env var
if [ -n "$ITERM_SESSION_ID" ] && [[ "$ITERM_SESSION_ID" =~ :([0-9A-F-]*) ]]
then
  iterm_id="${BASH_REMATCH[1]}"
fi

# update every $update_int seconds
while sleep $update_int
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

  # TODO: handle "60:86: execution error: iTerm got an error: Can’t get current window. (-1728)" error
  # (and clean up this logic)
  if [ -z "$fg_proc" ] && [[ -z "$iterm_id" || "$iterm_id" == "$(active_iterm_tab_id)" ]]
  then
    # need to do these calculations every time
    if [ -n "$date_fmt" ]
    then
      curr_datetime="$(date "$date_fmt")"
    else
      curr_datetime="$(date)"
    fi

    display_width="${#curr_datetime}"
    term_width="$(tput cols)"
    # plus 1 to account for the space on either side (plus 2 leaves 2 spaces to the right)
    col_offset="$(( $term_width - ($display_width + 1) ))"

    if [ "$col_offset" -gt 0 ]
    then
      move_cursor="$(printf "$move_cursor_str" "$col_offset")"
      # do the positioning and output all in one go, outputting to stderr
      # (with a space before and after the date for readability)
      echo -en "${save_cursor}${move_cursor} ${curr_datetime} ${restore_cursor}" >&2
    fi
  fi
done
