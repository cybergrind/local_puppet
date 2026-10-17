# Setup fzf
# ---------
if [[ ! "$PATH" == *$HOME/.fzf/bin* ]]; then
  PATH="${PATH:+${PATH}:}$HOME/.fzf/bin"
fi

# .zshrc already loads fzf when it's on PATH; only fall back to ~/.fzf/bin here
(( $+functions[fzf-history-widget] )) || source <(fzf --zsh)
