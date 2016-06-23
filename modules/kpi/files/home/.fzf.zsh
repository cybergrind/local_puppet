# Setup fzf
# ---------
if [[ ! "$PATH" == */home/kpi/.fzf/bin* ]]; then
  export PATH="$PATH:/home/kpi/.fzf/bin"
fi

# Man path
# --------
if [[ ! "$MANPATH" == */home/kpi/.fzf/man* && -d "/home/kpi/.fzf/man" ]]; then
  export MANPATH="$MANPATH:/home/kpi/.fzf/man"
fi

# Auto-completion
# ---------------
[[ $- == *i* ]] && source "/home/kpi/.fzf/shell/completion.zsh" 2> /dev/null

# Key bindings
# ------------
source "/home/kpi/.fzf/shell/key-bindings.zsh"

