# tramp fix
[[ $TERM == "dumb" ]] && unsetopt zle && PS1='$ ' && return

# ITERM fix
if [ ! -z "$Apple_PubSub_Socket_Render" ]; then
    declare -x PATH="/opt/local/bin:/opt/local/sbin:/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin"
fi
# Path to your oh-my-zsh configuration.
ZSH=$HOME/.oh-my-zsh

# Set name of the theme to load.
# Look in ~/.oh-my-zsh/themes/
# Optionally, if you set this to "random", it'll load a random theme each
# time that oh-my-zsh is loaded.
# ZSH_THEME="tonotdo"
# ZSH_THEME="random"
ZSH_THEME="jonathan"

# Set to this to use case-sensitive completion
# CASE_SENSITIVE="true"

# Comment this out to disable weekly auto-update checks
# DISABLE_AUTO_UPDATE="true"

# Uncomment following line if you want to disable colors in ls
# DISABLE_LS_COLORS="true"

# Uncomment following line if you want to disable autosetting terminal title.
# DISABLE_AUTO_TITLE="true"

# Uncomment following line if you want red dots to be displayed while waiting for completion
# COMPLETION_WAITING_DOTS="true"

# Which plugins would you like to load? (plugins can be found in ~/.oh-my-zsh/plugins/*)
# Example format: plugins=(rails git textmate ruby lighthouse)
plugins=(git archlinux ssh-agent fabric python postgres rsync svn extract docker golang go lein mvn pip scala sudo systemd zsh_reload z)

source $ZSH/oh-my-zsh.sh

export HISTSIZE=9999999

export PYTHONPATH=.
export EDITOR='emacsclient --alternate-editor="" -nw -c'
export PYMACS_PYTHON='python2'
export BROWSER="firefox-nightly"
export DIA_DIR=.

export JAVA_HOME=/usr/lib/jvm/java-8-jdk
export JDK_HOME=/usr/lib/jvm/java-8-jdk
#export LC_CTYPE=en_US.UTF-8
alias em='emacs -nw'

alias aenv='. ./venv/bin/activate || . ./bin/activate'


if [ -f /usr/share/nvm/init-nvm.sh ]; then
   source /usr/share/nvm/init-nvm.sh
fi

function jobskill {
    kill -9 `jobs -p | awk '{print $3}'`
}

alias lsg='ls -lah | grep -i $1'

function mk_chroot_ssh_screen {
    ssh -t $1 "sudo cp `tty` /lxc/kpi_chmod/dev/pts; sudo chroot /lxc/kpi_chmod /usr/bin/screen -D -RR " $2
}
function mk_ssh_screen {
    ssh -t $1 "/usr/bin/screen -D -RR " $2
}

function mk_ssh_screen_pf {
    ssh -L $3 -t $1 "/usr/bin/screen -D -RR " $2
}
function pid_kill_rm_nohup {
    pid_kill $%
    rm nohup.out
}
function rmpyc {
    find . -name \*.pyc -exec rm {} \;
}

function rmtmp {
    find . -name \*.pyc -delete
    find . -name \*~ -delete
    find . -name "\#*" -delete
    true
}

function do_tgz {
    rm $1; tar --exclude-vcs -czf $1 *
}

function h {
    case $# in
        0)
            history;;
        1)
            history | grep $1;;
        2)
            IFS=$'\n';
            _arr=( $(history | grep $1 | cut -f 4- -d ' ') );
            _num=${_arr[$2]};
            eval $_num;;
    esac;
}

function findi {
    case $# in
        0)
            find;;
        1)
            find . -iname "*$1*";;
        2)
            find $1 -iname "*$2*";;
    esac;
}


alias hz1="mk_ssh_screen hz1 gitlab"
alias 9p='mk_ssh_screen_pf 9p proj 9090:localhost:9090'
alias h1='mk_ssh_screen_pf h1 proj 9090:localhost:9090'
alias pk="pid_kill_rm_nohup"
alias new_screen="screen -c ~/.screenrc2 $@"

function am {
    case $# in
        0)
            ssh kb -t 'sudo su - ec2-user'
            ;;
        *)
            ssh $@ -t 'sudo su - ec2-user'
            ;;
    esac;
}

alias make_bw_tgz='tar czf bw.tgz bw && mv bw.tgz ../fabric_common/binary/.'
alias e='emacsclient --alternate-editor="" -nw -c "$@"'


export PATH=`echo ~`/bin:`echo ~/.local/bin`:/opt/android-sdk/platform-tools/:$PATH
# Customize to your needs...
[[ -s "$HOME/.rvm/scripts/rvm" ]] && . "$HOME/.rvm/scripts/rvm" # Load RVM function

if [[ "$TERM" == "dumb" ]]
then
  unsetopt zle
  unsetopt prompt_cr
  unsetopt prompt_subst
  unfunction precmd
  unfunction preexec
  PS1='$ '
fi
export LC_ALL=en_US.UTF-8
export LANG=en_US.UTF-8

function active-window-id {
if [ ! -n "$SSH_CLIENT" ] || [ ! -n "$SSH_TTY" ]; then
echo `xprop -root | awk '/_NET_ACTIVE_WINDOW\(WINDOW\)/{print $NF}'`
fi
}


export TERM=xterm-256color

# pip zsh completion start
function _pip_completion {
  local words cword
  read -Ac words
  read -cn cword
  reply=( $( COMP_WORDS="$words[*]" \
             COMP_CWORD=$(( cword-1 )) \
             PIP_AUTO_COMPLETE=1 $words[1] ) )
}
compctl -K _pip_completion pip
# pip zsh completion end


export PATH="$PATH:$HOME/.rvm/bin" # Add RVM to PATH for scripting

export GELF_HOST=192.168.88.26
export LOGSTASH_HOST=192.168.88.26
export DOCKER_NETWORK_DRIVER=overlay

function dck_tmp {
    docker run --rm=true $3 $4 $5 $6 -it $1 $2
}

function dck_bash_tmp {
    docker run  $2 $3 $4 $5 $6 --rm=true -it $1 /bin/bash
}

function dcup {
    C=/home/kpi/ssd/tipsi/tipsi_util/scripts/compose-cmd.sh
    NAME=$1
    shift
    $C $NAME up $@
}

function dcrup {
    C=/home/kpi/ssd/tipsi/tipsi_util/scripts/compose-cmd.sh
    NAME=$1
    shift
    $C $NAME build &&  $C $NAME up $@
}

function vpn_connect {
    /opt/cisco/anyconnect/bin/vpn connect https://by1-vpn.wargaming.net
}

function vpn_disconnect {
    /opt/cisco/anyconnect/bin/vpn disconnect
}

function dpms {
  case $1 in
   n) xset dpms 180 180 180;;
   l) xset dpms 1800 1800 1800;;
   f) xset dpms 6400 6400 6400;;
   off) xset dpms force off;;
  esac;
}

function my_track_organize {
    mkdir -p $1
    mv $1*png $1/.
}

# docker exec autocompletion
function _de_completion {
    containers=( $(docker ps | awk 'NR>1{print $NF}') )
    reply=( $containers )
}
function de {
    docker exec -it $1 /bin/bash
}
compctl -K _de_completion de
# docker exec completion end


function tcp_ports {
    sudo lsof -i -n -P | grep TCP
}

function lang_setup {
    setxkbmap 'us,ru(winkeys)' -option grp:toggle,grp_led:scroll,ctrl:nocaps
}

function leftmode {
    xmodmap -e 'pointer = 3 2 1'
    synclient TapButton1=3 TapButton2=1 TapButton3=2
    lang_setup
}

function rightmode {
    xmodmap -e 'pointer = 1 2 3'
    synclient TapButton1=1 TapButton2=3 TapButton3=2
    lang_setup
}

function _exists {
    whence $1 > /dev/null
}

function aws_setup {
    if [[ $AWS_READY == 1 ]]; then
        exit 0
    fi
    if [[ -f ~/.keys/env ]]; then
        source ~/.keys/env
    else
        echo 'There is no env files'
        exit 1
    fi

    if _exists awless; then
        source <(awless completion zsh)
    fi
    export AWS_READY=1
}

function awless_instances {
    prev=$(awless config get region)
    echo 'Region: ' $1
    awless config set region $1
    awless list instances
    awless config set region $prev
}

function aws_status {
    aws_setup
    awless_instances us-east-1
    awless_instances eu-central-1
}

# C-u to kill line from cursor to beginning
bindkey \^U backward-kill-line


export FZF_DEFAULT_COMMAND='ag --hidden --ignore .git -f -g ""'
[ -f ~/.fzf.zsh ] && source ~/.fzf.zsh

if [ -f /usr/share/nvm/nvm.sh ]; then
    [ -z "$NVM_DIR" ] && export NVM_DIR="$HOME/.nvm"
    source /usr/share/nvm/nvm.sh
    source /usr/share/nvm/bash_completion
    source /usr/share/nvm/install-nvm-exec
fi

CUSTOM_CONFIG="$HOME/.config/$(hostname).sh"
[ -f "$CUSTOM_CONFIG" ] && source "$CUSTOM_CONFIG" || echo 'no custom config'
