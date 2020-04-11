#!/usr/bin/env bash -x

UTIL_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null 2>&1 && pwd )"

files=(".gitignore_global" ".vip" ".emacs" ".bash_profile" ".bash_prompt")
for f in "${files[@]}"
do
    ln -s $UTIL_DIR/$f ~
done

git config --global include.path $UTIL_DIR/.gitconfig
