#!/bin/bash
set -euo pipefail
IFS=$'\n\t'

# This script attempts to parse all of the source files found under $ARCHIVES
# using an OCaml compiler found in $OCAMLREPO.

export ARCHIVES=./archives
export OCAMLREPO=$HOME/dev/ocaml

# At the time of writing this script, there are about 121715 sources files in
# $ARCHIVES, obtained by downloading the latest version of every opam package.
# The list of files is split into 32K blocks by GNU parallel, which gives rise
# to 262 jobs, dispatched in parallel to the processors. The time spent building
# the file list and running an empty parallel loop is about 3 seconds.

# Global logs of successes and failures, containing one line per source file.

rm -f successes failures
touch successes failures

# Remove any leftover per-worker logs.

rm -f /tmp/successes.* /tmp/failures.*

# This is the loop body. It is fed a block of file names on the standard input.

body() {
  echo "Hello, one worker is starting."
  # Create per-worker logs of successes and failures.
  # (This might reduce contention and save time.)
  mysuccesses=`mktemp /tmp/successes.XXX`
  myfailures=`mktemp /tmp/failures.XXX`
  # Read a file name $f from standard input.
  while read f ; do
    # Echo the file name. (This output is delayed by GNU parallel.)
    echo $f
    # Parse this file; log parse tree or error message to $f.ast.
    if $OCAMLREPO/boot/ocamlrun $OCAMLREPO/ocamlc \
      -nostdlib -nopervasives -stop-after parsing -dparsetree \
      $f 2>$f.ast ; \
    then
      echo $f >> $mysuccesses
    else
      echo "Exit code: $?" >> $f.ast
      echo $f >> $myfailures
    fi
  done
  # Dump the per-worker logs.
  cat $mysuccesses >> successes
  cat $myfailures >> failures
  rm $mysuccesses $myfailures
  # Display a progress report.
  echo "Bye, one worker is done."
  wc -l successes
  wc -l failures
}
export -f body

# Use gfind if available.

if command -v gfind >/dev/null ; then
  FIND=gfind
else
  FIND=find
fi

# This is the main parallel loop.

echo "Building file list..."
$FIND $ARCHIVES -type f -regex ".*\.mli?" \
   | parallel --no-notice --pipe --block-size 8192 body

# Statistics.

printf "Successfully parsed %d files (cat successes).\n" `wc -l successes | cut -d ' ' -f 1`
printf "Failed to parse %d files (cat failures).\n" `wc -l failures | cut -d ' ' -f 1`
