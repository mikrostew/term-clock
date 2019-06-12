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

# TODO: this should be in a separate script, so I can call it instead of sourcing and calling the function
source "$HOME/dotfiles/.bash_repo_status"

# update every $update_int seconds
while sleep $update_int
do
  # if the parent shell has exited, then this should exit as well
  # otherwise this will continue running when the session exits, because it has open terminal file handles
  # (see https://stackoverflow.com/a/8123399)
  if ! kill -0 $shell_pid 2>/dev/null; then exit 0; fi

  # if there is a foreground process running, don't update the clock
  # (adapted from https://unix.stackexchange.com/a/273785)
  #  state shows the state, where '+' means running in the foreground
  #  ppid shows the parent PID (to grep for the pid of the shell)
  #  comm shows the command (but not the arguments, so this doesn't match the grep)
  # this greps for the shell PID, filters out the bash process running the clock, and looks for any FG process
  fg_proc="$(ps -e -o state= -o ppid= -o comm= | grep -Fw $shell_pid | grep -v "bash" | grep -F '+')"

  # and only update the clock if the iTerm tab is the active one
  active_tab_id="$(active_iterm_tab_id 2>/dev/null)"

  # if there are no FG processes, and
  # either there is no Iterm ID, or that ID is the active tab
  if [ -z "$fg_proc" ] && [[ -z "$iterm_id" || "$iterm_id" == "$active_tab_id" ]]
  then
    # need to do these calculations every time
    if [ -n "$date_fmt" ]
    then
      curr_datetime="$(date "$date_fmt")"
    else
      curr_datetime="$(date)"
    fi

    # track the CWD of the parent process
    # (from https://unix.stackexchange.com/q/94357)
    parent_pwd="$(lsof -p $shell_pid | awk '$4=="cwd" {print $9}')"
    cd "$parent_pwd"

    # TODO: this should be passed in as an option, instead of hard-coded
    full_status="$(repo_status)    $curr_datetime"

    #  this strips out any colors and escape codes before calculating the length,
    #  because those are counted too, even though they are not printable
    #  (from https://stackoverflow.com/q/17998978)
    #
    #  the leading dollar sign is to interpret the escape sequences
    #  (see https://stackoverflow.com/q/11966312)
    full_status_nocolor="$(echo "$full_status" | sed $'s/\x1b\\[[0-9;]*[mGK]//g' )"

    display_width="${#full_status_nocolor}"
    term_width="$(tput cols)"
    # plus 1 to account for the space on either side (plus 2 leaves 2 spaces to the right)
    col_offset="$(( $term_width - ($display_width + 1) ))"

    if [ "$col_offset" -gt 0 ]
    then
      move_cursor="$(printf "$move_cursor_str" "$col_offset")"
      # do the positioning and output all in one go, outputting to stderr
      # (with a space before and after the date for readability)
      echo -en "${save_cursor}${move_cursor} ${full_status} ${restore_cursor}" >&2
    fi
  fi
done
