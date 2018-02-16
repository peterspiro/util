#!/usr/bin/env bash

UTIL_DIR=$(dirname $BASH_SOURCE)
export UTIL_DIR

files=( ".gitconfig" ".gitignore_global" ".vip" ".emacs" ".bash_profile")
ln -s $UTIL_DIR/.gitignore_global ~

