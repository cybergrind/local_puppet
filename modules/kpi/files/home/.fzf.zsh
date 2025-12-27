# Setup fzf
# ---------
if [[ ! "$PATH" == */home/kpi/.fzf/bin* ]]; then
  PATH="${PATH:+${PATH}:}/home/kpi/.fzf/bin"
fi

source <(fzf --zsh)
