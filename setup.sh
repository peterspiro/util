# Run with:
# 	bash setup.sh

set -x
set -e


UTIL_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null 2>&1 && pwd )"


cp .bash_profile ~

files=(".gitignore_global" ".vip" ".emacs" ".bash_prompt")
for f in "${files[@]}"
do
    ln -s $UTIL_DIR/$f ~
done


git config --global include.path $UTIL_DIR/.gitconfig


cd $UTIL_DIR

git config user.email peterspiro@users.noreply.github.com
git config user.name "Peter Spiro"


chsh -s /bin/bash
