# CybroidOS zsh (citos-plasma): the shell for new accounts. Yours to change.
#
#   As you type, a command you have run before shows in grey after the
#   cursor: Tab (or →) takes it. With nothing suggested, Tab completes.
#   ↑ and ↓ go through the commands that start with what you have typed.
#   Commands are coloured as you type: green when they exist, red when not.

# --- options --------------------------------------------------------------
setopt autocd interactivecomments magicequalsubst nonomatch notify
setopt numericglobsort promptsubst
WORDCHARS=${WORDCHARS//\/}   # Ctrl+W stops at a slash
PROMPT_EOL_MARK=""

# --- keys -----------------------------------------------------------------
bindkey -e
bindkey '^[[1;5C' forward-word        # Ctrl+→
bindkey '^[[1;5D' backward-word       # Ctrl+←
bindkey '^[[H' beginning-of-line      # Home
bindkey '^[[F' end-of-line            # End
bindkey '^[[3~' delete-char           # Delete
bindkey '^[[3;5~' kill-word           # Ctrl+Delete
bindkey '^H' backward-kill-word       # Ctrl+Backspace
bindkey '^[[Z' undo                   # Shift+Tab

# ↑ and ↓ through the history that starts with what is typed.
autoload -Uz up-line-or-beginning-search down-line-or-beginning-search
zle -N up-line-or-beginning-search
zle -N down-line-or-beginning-search
bindkey '^[[A' up-line-or-beginning-search
bindkey '^[[B' down-line-or-beginning-search
bindkey '^[OA' up-line-or-beginning-search
bindkey '^[OB' down-line-or-beginning-search

# --- completion -----------------------------------------------------------
mkdir -p "${XDG_CACHE_HOME:-$HOME/.cache}/zsh"
autoload -Uz compinit
compinit -d "${XDG_CACHE_HOME:-$HOME/.cache}/zsh/zcompdump"
zstyle ':completion:*' menu select
zstyle ':completion:*' matcher-list 'm:{a-zA-Z}={A-Za-z}'   # any case
zstyle ':completion:*' list-colors "${(s.:.)LS_COLORS}"
zstyle ':completion:*' group-name ''
zstyle ':completion:*:descriptions' format '%F{cyan}%d%f'
zstyle ':completion:*' rehash true
zstyle ':completion:*' use-cache on
zstyle ':completion:*' cache-path "${XDG_CACHE_HOME:-$HOME/.cache}/zsh"

# --- history --------------------------------------------------------------
HISTFILE=~/.zsh_history
HISTSIZE=10000
SAVEHIST=20000
setopt hist_expire_dups_first hist_ignore_dups hist_ignore_space hist_verify
setopt share_history extended_history
alias history="history 0"

# --- prompt ---------------------------------------------------------------
# ┌──(you@computer)-[~/folder]
# └─$                          (# and red when you are root)
PROMPT=$'%F{%(#.blue.cyan)}┌──(%B%F{%(#.red.blue)}%n%(#.#.@)%m%b%F{%(#.blue.cyan)})-[%B%F{reset}%(6~.%-1~/…/%4~.%5~)%b%F{%(#.blue.cyan)}]\n%F{%(#.blue.cyan)}└─%B%(#.%F{red}#.%F{blue}$)%b%F{reset} '
# The last command's status at the right when it failed.
RPROMPT=$'%(?..%F{red}✗ %?%f)'

# --- colours --------------------------------------------------------------
if [ -x /usr/bin/dircolors ]; then
	eval "$(dircolors -b)"
	alias ls='ls --color=auto'
	alias grep='grep --color=auto'
	alias diff='diff --color=auto'
	alias ip='ip --color=auto'
fi
alias ll='ls -lh'
alias la='ls -A'
alias l='ls -CF'

# --- suggestions from history (grey), Tab to take them ---------------------
if [ -f /usr/share/zsh-autosuggestions/zsh-autosuggestions.zsh ]; then
	. /usr/share/zsh-autosuggestions/zsh-autosuggestions.zsh
	ZSH_AUTOSUGGEST_HIGHLIGHT_STYLE='fg=#6b7a9c'
	ZSH_AUTOSUGGEST_STRATEGY=(history completion)
	# Tab: take the grey suggestion when there is one, else complete.
	_cybroid_tab() {
		if [[ -n $POSTDISPLAY ]]; then
			zle autosuggest-accept
		else
			zle expand-or-complete
		fi
	}
	zle -N _cybroid_tab
	bindkey '^I' _cybroid_tab
fi

# --- colours as you type (last: it wraps the other widgets) ----------------
if [ -f /usr/share/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh ]; then
	. /usr/share/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh
	ZSH_HIGHLIGHT_HIGHLIGHTERS=(main brackets pattern)
	ZSH_HIGHLIGHT_STYLES[default]=none
	ZSH_HIGHLIGHT_STYLES[unknown-token]=fg=red,bold
	ZSH_HIGHLIGHT_STYLES[command]=fg=green,bold
	ZSH_HIGHLIGHT_STYLES[builtin]=fg=green,bold
	ZSH_HIGHLIGHT_STYLES[alias]=fg=green,bold
	ZSH_HIGHLIGHT_STYLES[path]=underline
	ZSH_HIGHLIGHT_STYLES[comment]=fg=#6b7a9c,italic
fi
