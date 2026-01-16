# tramp fix
if [[ $TERM == "dumb" ]]; then
    unsetopt zle
    unsetopt prompt_cr
    unsetopt prompt_subst
    unfunction precmd
    unfunction preexec
    PS1='$ '
    return
fi

# ITERM fix
if [ ! -z "$Apple_PubSub_Socket_Render" ]; then
    declare -x PATH="/opt/local/bin:/opt/local/sbin:/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin"
fi

if [[ $OSTYPE == "darwin"* ]]; then
    declare -x PATH=$PATH:/opt/homebrew/bin:/opt/puppetlabs/bin
fi

if [[ -f ~/.keys/env ]]; then
    source ~/.keys/common_env
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
plugins=(
    aliases
    alias-finder
    archlinux
    bgnotify
    extract
    fabric
    fzf
    git
    golang
    kubectl
    lein
    mvn
    pip
    postgres
    python
    rsync
    scala
    ssh-agent
    sudo
    svn
    systemd
    wd
    uv
    z
)
zstyle ':omz:plugins:alias-finder' autoload yes # disabled by default
zstyle ':omz:plugins:alias-finder' longer yes # disabled by default
zstyle ':omz:plugins:alias-finder' exact yes # disabled by default
zstyle ':omz:plugins:alias-finder' cheaper yes # disabled by default


FZF_WD_BINDKEY='^q'

if [ ! -z $ZSH/oh-my-zsh.sh ]; then
    source $ZSH/oh-my-zsh.sh
fi


if [ ! -z "$SSH_CLIENT" ]; then
    declare -x PR_CYAN=$PR_LIGHT_RED
fi


export HISTSIZE=9999999
export PYTHONPATH=.
export EDITOR='emacsclient --alternate-editor="" -nw -c'
export BROWSER="brave"
export DIA_DIR=.
export PKGEXT='.pkg.tar'
export EMACS_EXTRA_LANGS=1

#export JAVA_HOME=/usr/lib/jvm/java-8-jdk
#export JDK_HOME=/usr/lib/jvm/java-8-jdk

export LC_ALL=en_US.UTF-8
export LANG=en_US.UTF-8
export TERM=xterm-256color

#export LC_CTYPE=en_US.UTF-8

function jobskill {
    kill -9 `jobs -p | awk '{print $3}'`
}

function mk_ssh_screen {
    case $# in
        1) SCREEN_NAME=default ;;
        *) SCREEN_NAME=$2;;
    esac
    ssh -t $1 "/usr/bin/screen -D -RR ${@:2} ${SCREEN_NAME}"
}

function mk_ssh_screen_x {
    ssh -t $1 "/usr/bin/screen -D -RR ${@:2} ${2}"
}

function mk_ssh_screen_pf {
    ssh -L $3 -t $1 "/usr/bin/screen -D -RR " $2
}

function pid_kill_rm_nohup {
    pid_kill $%
    rm nohup.out
}

function rmpyc {
    fd -I -e \.pyc -x rm {}
}

function rmtmp {
    case $@ in
        sudo) sudo chown `whoami` -R . ;;
    esac;

    rmpyc
    fd -I '~$' -x rm {}
    fd -I "#.*#" -x rm {}
    fd -I '__pycache__' -t d -x rm -r {}
    true
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


function new_tmux_session {
    # 0 - start base session
    # 1 - name
    # 2 - config
    # 3 - socket name
    case $# in
        0)
            new_tmux_session wk ~/.config/tmux/tmux2.conf wk;;
        1)
            tmux -L default new-session -A -t $1;;
        2)
            tmux -f $2 -L $1 new -A -t $1;;
        3)
            tmux -L $3 -f $2 -L $1 new -A -t $1;;
    esac;
}
function _new_tmux_session {
    local values=( $(tmux -L default list-sessions -F "#S") )
    reply=( $values )
}
compctl -K _new_tmux_session new_tmux_session

# UV related
alias upc='uv run pre-commit run'
alias upca='uv run pre-commit run -a'
alias uvt='uv run pytest'


alias em='emacs -nw'
alias tmx='new_tmux_session'

alias lsg='ls -lah | ag -i $1'

alias hz1="mk_ssh_screen hz1 gitlab"
alias 9p='mk_ssh_screen_pf 9p proj 9090:localhost:9090'
alias tpad_gitlab='mk_ssh_screen gitlab@tpad gitlab'
alias pk="pid_kill_rm_nohup"
alias new_screen="screen -c ~/.screenrc2 $@"

alias gln='set -o noglob'
alias gly='set +o noglob'

alias e='emacsclient --alternate-editor="" -nw -c "$@"'
alias ccd=/home/kpi/devel/tipsi/tipsi_util/scripts/compose-cmd.sh
alias tdev=/home/kpi/devel/tipsi/tipsi_util/helpers/init_dev.py

# kubernetes
alias kp='k get po -A -o wide'
alias kev="kubectl get events --sort-by='.metadata.creationTimestamp' -A"

alias allowme='wd wcm; ./venv/bin/python src/allow_me.py; cd -'


export PATH=`echo ~/.local/bin`:`echo ~/go/bin`:`echo ~`/bin:/opt/android-sdk/platform-tools/:$PATH
# Customize to your needs...

function active-window-id {
    if [ ! -n "$SSH_CLIENT" ] || [ ! -n "$SSH_TTY" ]; then
        echo `xprop -root | awk '/_NET_ACTIVE_WINDOW\(WINDOW\)/{print $NF}'`
    fi
}

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

# export DOCKER_NETWORK_DRIVER=overlay

function dck_tmp {
    docker run --rm=true $3 $4 $5 $6 -it $1 $2
}

function dck_bash_tmp {
    docker run  $2 $3 $4 $5 $6 --rm=true --entrypoint='' -it $1 /bin/bash
}



function dpms {
  case $1 in
   n) xset dpms 180 180 180;;
   l) xset dpms 1800 1800 1800;;
   f) xset dpms 6400 6400 6400;;
   off) xset dpms force off;;
  esac;
}

function mon_sleep {
    sleep 0.1
    xset s activate
    sleep 0.1
    xset dpms force suspend
}

# docker exec autocompletion
function _de_completion {
    containers=( $(docker ps | awk 'NR>1{print $NF}') )
    reply=( $containers )
}
function de {
    case $# in
        0)
            if [[ $# = 0 && ! -z "$DE_DEFAULT" ]]; then
                docker exec -it -e LINES=$(tput lines) -e COLUMNS=$(tput cols) $DE_DEFAULT /bin/bash
            else
                echo 'define $DE_DEFAULT variable to use without parameters'
            fi;;
        1)
            docker exec -it -e LINES=$(tput lines) -e COLUMNS=$(tput cols) $1 /bin/bash;;
        *)
            docker exec -it -e LINES=$(tput lines) -e COLUMNS=$(tput cols) $@ ;;
    esac
}
compctl -K _de_completion de

function dck {
    docker $@
}
compctl -K _de_completion dck
# docker exec completion end

function hupde {
    # send HUP signal to process 1
    if [[ -z "$DE_DEFAULT" ]]; then
        echo 'There is no $DE_DEFAULT defined'
        return 1
    fi
    docker kill -s HUP $DE_DEFAULT
}



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
        return 0
    fi
    if [[ -f ~/.keys/env ]]; then
        source ~/.keys/env
    else
        echo 'There is no env files'
        return 1
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

function bcc_tools {
    docker run -it --rm \
           --privileged \
           -v /lib/modules:/lib/modules:ro \
           -v /usr/src:/usr/src:ro \
           -v /etc/localtime:/etc/localtime:ro \
           --workdir /usr/share/bcc/tools \
           --pid host \
           zlim/bcc
}

# C-u to kill line from cursor to beginning
bindkey \^U backward-kill-line

HAS_FZF=$(which fzf)
HISTFILE=~/.zsh_history
setopt HIST_REDUCE_BLANKS        # remove superfluous blanks before recording entry.
setopt SHARE_HISTORY             # share history between all sessions.
setopt HIST_IGNORE_ALL_DUPS      # delete old recorded entry if new entry is a duplicate.

if [ -n "$HAS_FZF" ]; then
    export FZF_DEFAULT_OPTS='--height 80% --border'
    export FZF_DEFAULT_COMMAND='ag --hidden --silent --ignore .git -f -g ""'
    export FZF_CTRL_T_COMMAND='ag --hidden --silent --ignore .git -f -g ""'
    source < $(fzf --zsh)
else
	echo "NO FZF"
fi

function load_nvm {
    if [ -f /usr/share/nvm/nvm.sh ]; then
        [ -z "$NVM_DIR" ] && export NVM_DIR="$HOME/.nvm"
        source /usr/share/nvm/nvm.sh
        source /usr/share/nvm/bash_completion
        source /usr/share/nvm/install-nvm-exec
    fi
}

function load_rvm {
    if [ -s "$HOME/.rvm/scripts/rvm" ]; then
        . "$HOME/.rvm/scripts/rvm" # Load RVM function
        export PATH="$PATH:$HOME/.rvm/bin" # Add RVM to PATH for scripting
    fi
}


# uv enable file completion
_uv_run_mod() {
    if [[ "$words[2]" == "run" && "$words[CURRENT]" != -* ]]; then
        _arguments '*:filename:_files'
    else
        _uv "$@"
    fi
}
compdef _uv_run_mod uv


# $+commands[direnv] => 1
# $commands[direnv] => /usr/bin/direnv

if (( $+commands[direnv] )); then
    eval "$(direnv hook zsh)"
fi

if [ -d "$HOME/.nimble/bin" ]; then
    export PATH="$HOME/.nimble/bin:$PATH"
fi

if [ -d "$HOME/.cargo/bin/" ]; then
    export PATH="$HOME/.cargo/bin:$PATH"
fi

if (( $+commands[heroku] )); then
    HEROKU_AC_ZSH_SETUP_PATH=/home/kpi/.cache/heroku/autocomplete/zsh_setup && test -f $HEROKU_AC_ZSH_SETUP_PATH && source $HEROKU_AC_ZSH_SETUP_PATH || eval "$(heroku autocomplete:script zsh)"
fi

CUSTOM_CONFIG="$HOME/.config/$(hostname).sh"
if [ -f "$CUSTOM_CONFIG" ]; then
    source "$CUSTOM_CONFIG"
else
    echo 'no custom config'
fi

[ -f /opt/miniconda3/etc/profile.d/conda.sh ] && source /opt/miniconda3/etc/profile.d/conda.sh

[ -f ~/.fzf.zsh ] && source ~/.fzf.zsh
