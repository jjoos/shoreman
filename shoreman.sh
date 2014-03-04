#!/bin/bash

# [shoreman](https://github.com/hecticjeff/shoreman) is an
# implementation of the **Procfile** format. Inspired by the original
# [foreman](http://ddollar.github.com/foreman/) tool for ruby, as
# well as [norman](https://github.com/josh/norman) for node.js.

# Make sure that any errors cause the script to exit immediately.
set -e

# ## Usage

# Usage message that is displayed when `--help` is given as an argument.
usage() {
  echo "Usage: shoreman [<procfile>]"
  echo "Run Procfiles using shell."
  echo
  echo "The shoreman script reads commands from <procfile> and starts up the"
  echo "processes that it describes."
}

ENV_FILE='.env'
PROCFILE='Procfile'

# ## Read command line options

# We want to have a structured method to read command line arguments, we use
# getopt without the -l flag, since this breaks osx compatability.
read_command_line_options() {
  # read the options
  eval set -- "`getopt -o e:h -- $*`"

  # extract options and their arguments into variables.
  while true ; do
    case "$1" in
      -e)
        case "$2" in
            "") shift 2 ;;
            *) ENV_FILE=$2 ; shift 2 ;;
        esac ;;
      -h) usage ; exit 0 ;;
      --) shift ; break ;;
    esac
  done

  if [[ $1 != '' ]]; then PROCFILE="$1"; fi
  if [[ $2 != '' ]]; then ENV_FILE="$2"; fi
}
# ## Logging

# For logging we want to prefix each entry with the current time, as well
# as the process name. This takes one argument, the name of the process, and
# then reads data from stdin, formats it, and sends it to stdout.
log() {
  while read data
  do
    __TAB_CHARACTER=$'\t'
    echo "$(date +"%H:%M:%S") ${1}${__TAB_CHARACTER}| $data"
  done
}

# ## Running commands

# When a process is started, we want to keep track of its pid so we can
# `kill` it when the parent process receives a signal, and so we can `wait`
# for it to finish before exiting the parent process.
store_pid() {
  pids=("${pids[@]}" "$1")
}

# This starts a command asynchronously and stores its pid in a list for use
# later on in the script.
start_command() {
  bash -c "$1" &
  pid="$!"
  store_pid "$pid"
}

read_command_line_options "$@"

# ## Reading the .env file

# The .env file needs to be a list of assignments like in a shell script.
# The file is interpreted as a bash script and all asignments are exported
# automatically (set -a)
set -a
source $ENV_FILE || true
set +a

# ## Reading the Procfile

# The Procfile needs to be parsed to extract the process names and commands.
# The file is given on stdin, see the `<` at the end of this while loop.
while read line || [ -n "$line" ]; do
  name=${line%%:*}
  command=${line#*: }
  start_command "$command"
  echo "'${command}' started with pid ${pid}" | log "${name}.1"
done < "$PROCFILE"

# ## Cleanup

# When a `SIGINT`, `SIGTERM` or `EXIT` is received, this action is run, killing the
# child processes. The sleep stops STDOUT from pouring over the prompt, it
# should probably go at some point.
onexit() {
  echo SIGINT received
  echo sending SIGTERM to all processes
  kill ${pids[*]} &>/dev/null
  sleep 1
}
trap onexit SIGINT SIGTERM EXIT

# Wait for the children to finish executing before exiting.
wait
