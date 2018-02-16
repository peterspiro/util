#!/usr/bin/env bash

UTIL_DIR=$(dirname $BASH_SOURCE)
export UTIL_DIR

files=( ".gitconfig" ".gitignore_global" ".vip" ".emacs" ".bash_profile")
for f in "${files}"
do
    ln -s $UTIL_DIR/.gitignore_global ~
done

