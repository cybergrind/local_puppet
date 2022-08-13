
export PATH=$PATH:/opt/homebrew/bin/
eval "$(direnv hook zsh)"

BDIR=$(brew --prefix)

[ -s "$BDIR/opt/nvm/nvm.sh" ] && \. "$BDIR/opt/nvm/nvm.sh"

export PATH=$PATH:/Users/kpi/Library/Python/3.9/bin:/opt/homebrew/opt/emacs/bin
export PATH=$PATH:/Users/kpi/.cargo/bin
export PATH="$BDIR/opt/findutils/libexec/gnubin:$PATH"
