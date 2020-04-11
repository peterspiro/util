if [ -f ~/util/.bashrc ]; then
   source ~/util/.bashrc
fi

if [ -f ~/.bashrc ]; then
   source ~/.bashrc
fi

test -e "${HOME}/.iterm2_shell_integration.bash" && source "${HOME}/.iterm2_shell_integration.bash"
