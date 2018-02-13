# don't put duplicate lines in the history. See bash(1) for more options
export HISTCONTROL=ignoredups
# ... and ignore same successive entries.
#export HISTCONTROL=ignoreboth

source /usr/local/etc/bash_completion.d/git-completion.bash

set -o vi
set -o noclobber

#-----------------------------------
# Portable Aliases
#-----------------------------------

alias rm='rm -i'
alias mv='mv -i'
alias cp='cp -i'

alias grepc='grep -i --color=auto'
alias grep='grep -i'

alias l='ls -lh'
alias ll='ls -lh'
alias ls='ls -HGF'
alias la='ls -a'
alias lla='ll -a'
alias lr='ls -R'
alias md='mkdir -p'
alias ...='cd ../..'
alias ....='cd ../../..'
alias h='history'
alias whereami='curl -s http://api.hostip.info/get_html.php?ip=$1'
alias path='echo -e ${PATH//:/\\n}'
alias vi=vim
alias edit='vim'
alias svi='sudo vi'
alias ports='netstat -tulap tcp'
alias durev='du -s * | sort -rn'
alias httpdreload='sudo /usr/sbin/apachectl -k graceful'

alias psync='auto_rsync -n aws-project -s 0.2 -l -w ~/PycharmProjects/project/project -u user -r aws-project:/<root-path>/project/project'
alias psynck='auto_rsync -n aws-project --unload'

alias sshp='ssh user@aws-project'

#-----------------------------------
# OS X Aliases
#-----------------------------------

alias psmem='ps aux | sort -nr -k 4'
alias pscpu='ps aux | sort -nr -k 3'

# Top 10 memory and CPU consuming processes. Good for Geektool. On Linux, use auxf.
alias psmem10='ps aux | sort -nr -k 4 | head -10'
alias pscpu10='ps aux | sort -nr -k 3 | head -10'

# a less cpu intensive top. BSD-specific?
alias ttop='top -ocpu -R -F -s 2 -n30'

# Miscellaneous commands
alias spot='mdfind -onlyin `pwd`'

# Delete all .DS_Store files in current dir and its children
alias ds_store_rm='find . -name '.DS_Store' -print0 | xargs -t0 rm'

#-----------------------------
# Machine Specific Functions
#   i.e., may require additional setup of MySQL, Python, Java, etc.
#-----------------------------

# Log SQL statements. If local MySQL, you must connect with --protocol=tcp. Assumes Wireshark installed.
alias mysqllog="sudo tshark -i lo0 -V -f 'dst port 3306' | egrep 'Statement:|Statement \[truncated\]:'"

# Start and stop MySQL
alias mysql_start="/Library/StartupItems/MySQLCOM/MySQLCOM start"
alias mysql_stop="/Library/StartupItems/MySQLCOM/MySQLCOM stop"

alias sock='ln -s /opt/local/var/run/mysql5/mysqld.sock /tmp/mysql.sock'

#-----------------------------------
# Portable Functions
#-----------------------------------

# cd's up directory path by the specified number of levels. Defaults to 1.
function ..() {
  local arg=${1:-1};
  while [ $arg -gt 0 ]; do
  cd .. >&/dev/null;
  arg=$(($arg - 1));
  done
}

# Usage:
#    $ some_command ; notify
# After the command finishes, email is sent to space-delimited list of email addresses in mail variable
# Especially useful if you use a mobile carrier address that sends you a text message
# For example, nnnnnnnnnn@messaging.sprintpcs.com
function notify() {
    # NOTE!!! Set mail var to desired list of email addresses.
    mail="rstewart@castlighthealth.com 5102903391@messaging.sprintpcs.com"
    str1="`history 1 | cut -b 8-`"
    str2="${str1%;*}"
    echo ${str2} | mail -s CMD_FINISH ${mail}
}

# bash function to decompress archives - http://www.shell-fu.org/lister.php?id=375
function extract() {
    if [ -f $1 ] ; then
        case $1 in
            *.tar.bz2)   tar xvjf $1    ;;
            *.tar.gz)    tar xvzf $1    ;;
            *.bz2)       bunzip2 $1     ;;
            *.rar)       unrar x $1     ;;
            *.gz)        gunzip $1      ;;
            *.tar)       tar xvf $1     ;;
            *.tbz2)      tar xvjf $1    ;;
            *.tgz)       tar xvzf $1    ;;
            *.txz)       tar xfJ $1     ;;
            *.zip)       unzip $1       ;;
            *.Z)         uncompress $1  ;;
            *.7z)        7z x $1        ;;
            *)           echo "'$1' cannot be extracted via >extract<" ;;
        esac
    else
        echo "'$1' is not a valid file"
    fi
}

#-------------------------
# OS X Specific Functions
#-------------------------

# Define colors for custom prompt
#red='\[\e[0;31m\]'
#RED='\[\e[1;31m\]'
#blue='\[\e[0;34m\]'
#BLUE='\[\e[1;34m\]'
#cyan='\[\e[0;36m\]'
#CYAN='\[\e[1;36m\]'
#NC='\[\e[0m\]'              # No Color

function customprompt() {
    # Set the window title to user, host and relative path (Use \W for full path)
    TITLE="\u@\h: \w"

    #  \[...\] tells bash to ignore non-printing control characters when calculating prompt width.
    #  Otherwise, line editing commands get confused while placing the cursor.
    LINE_PROMPT="${cyan}\u@\h:\w\n${red}[\!] \$ ${NC}"

    # Set up PS1 to do the window title and line prompt
    case $TERM in
        xterm*)
            PS1="\[\033]0;$TITLE\007\]$LINE_PROMPT"
            ;;
        *)
            PS1="$LINE_PROMPT"
            ;;
    esac
}

# Set custom prompt
customprompt

# Open man page in TextMate.
#   arg1 = command name
function mateman() {
    MANWIDTH=160 MANPAGER='col -bx' man $@ | mate
}

# Quit OS X apps from command line.
#   vararg = app names
function quit() {
    for app in $*; do
       osascript -e 'quit app "'$app'"'
    done
}

# Relaunch OS X apps from command line.
#   vararg = app names
function relaunch() {
    for app in $*; do
        osascript -e 'quit app "'$app'"';
        sleep 3;
        open -a $app
    done
}

# spotlight powered locate
function slocate() {
    mdfind "kMDItemDisplayName == '$@'wc";
}

# cd's to frontmost window of Finder
function cdf() {
    cd "`osascript -e 'tell application "Finder"' \
    -e 'set myname to POSIX path of (target of window 1 as alias)' \
    -e 'end tell' 2>/dev/null`"
}

# Moves files to trash, rather than immediately deleting them
function trash () {
    local path
    for path in "$@"; do
        # ignore any arguments
        if [[ "$path" = -* ]];
        then :
        else local dst=${path##*/}
            # append the time if necessary
            while [ -e ~/.Trash/"$dst" ]; do
                dst="$dst "$(date +%H-%M-%S)
            done
            mv "$path" ~/.Trash/"$dst"
        fi
    done
}

#-----------------------------
# Machine Specific Functions
#   i.e., may require additional setup of MySQL, Python, Java, Git, etc.
#-----------------------------

# Return list of queries actually executing on a MySQL server
#   arg1 = user
#   arg2 = host, will use localhost if omitted
function dbq() {
    echo "SHOW PROCESSLIST" | mysql -u $1 -h ${2:-localhost} -p -t | grep -E "(^\| Id|^\+|Query)"
}

function find_git_branch_new {
    git_branch=git branch 2> /dev/null |grep '*'|sed 's/../[/;s/$/]/'
}

function find_git_branch {
    local dir=. head
    until [ "$dir" -ef / ]; do
        if [ -f "$dir/.git/HEAD" ]; then
            head=$(< "$dir/.git/HEAD")
            if [[ $head == ref:\ refs/heads/* ]]; then
                git_branch="[${head##*/}]"
            elif [[ $head != '' ]]; then
                git_branch='[detached]'
            else
                git_branch='[unknown]'
            fi
            return
        fi
        dir="../$dir"
    done
    git_branch=''
}

BLACK='\[\e[0;30m\]'
GREEN='\[\e[0;32m\]'

source $UTIL_DIR/.bash_prompt


# Show all git branches by last modified date
# > recent_branches
function recent_branches() {
  for k in `git branch -r|perl -pe s/^..//`;do echo -e `git show --pretty=format:"%Cgreen%ci %Cblue%cr%Creset" $k|head -n 1`\\t$k;done|sort
}

# Pretty prints JSON from one file to another, or to stdout
#   arg1 = file name with ugly JSON
#   arg2 = file name to which to write pretty JSON. If none specified, write to stdout.
function prettyjson() {
    if [ "$2" != "" ]; then
        cat $1 | python -mjson.tool > $2
    else
        cat $1 | python -mjson.tool 2>&1
    fi
}

# alias to get back the pylint error codes

alias pylint='pylint --msg-template "{msg_id}:{line:3d},{column}: {obj}: {msg}"'
alias pylint_no_todo='pylint -d W0511 --msg-template "{msg_id}:{line:3d},{column}: {obj}: {msg}"'

alias nose='nosetests omicia_pipeline integration_tests'
alias noseq='nosetests omicia_pipeline integration_tests 2>&1 |grep -v "^omicia_pipeline"'
alias nosevq='nosetests omicia_pipeline integration_tests 2>&1 |egrep -v "^([a-z =>]|[A-Z][a-z]|$|\-)"'

# ls with colors!

export CLICOLOR=1
export LSCOLORS=gxBxhxDxfxhxhxhxhxcxcx
