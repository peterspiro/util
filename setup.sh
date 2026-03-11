# Run with:
# 	bash setup.sh

set -x
set -e


UTIL_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null 2>&1 && pwd )"


cp .bash_profile ~

shopt -s dotglob
for path in dotfiles/*; do
  base=$(basename "$path")
  if [[ ! -f ~/$base ]]; then
    ln -s $UTIL_DIR/$path ~
  fi
done


git config --global include.path $UTIL_DIR/.gitconfig


cd $UTIL_DIR

git config user.email peterspiro@users.noreply.github.com
git config user.name "Peter Spiro"


if [[ "$SHELL" != "/bin/bash" ]]; then
  chsh -s /bin/bash
fi
