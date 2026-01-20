#!/usr/bin/env zsh

SESSION="cluster_ssh_${1:-8}"
MODE=${1:-"8"} 

# Gruppen-Definition
MACS=("archmba-fama-wlan" "debianmba-fama-wlan" "debianmbp-fama-wlan")
RSPBS=("rspb01-fama-lan" "rspb02-fama-lan" "rspb03-fama-lan")

# Host-Auswahl basierend auf Parameter
if [[ "$MODE" == "3" ]]; then
    HOSTS=($RSPBS)
elif [[ "$MODE" == "6" ]]; then
    HOSTS=($MACS $RSPBS)
else
    HOSTS=("archmba-fama-wlan" "debianmba-fama-wlan" "debianmbp-fama-wlan" "debianthink-fama-wlan" "macmini-fama-lan" "rspb01-fama-lan" "rspb02-fama-lan" "rspb03-fama-lan")
fi

typeset -A HOST_CMDS
HOST_CMDS=(
    [archmba-fama-wlan]="reset; fastfetch"
    [debianmba-fama-wlan]="source ~/.zshrc; nosleep start; reset; fastfetch"
    [debianmbp-fama-wlan]="source ~/.zshrc; nosleep start; reset; fastfetch"
    [debianthink-fama-wlan]="source ~/.zshrc; nosleep start; reset; fastfetch"
    [macmini-fama-lan]="/usr/bin/reset; /opt/homebrew/bin/fastfetch"
    [rspb01-fama-lan]="reset; fastfetch"
    [rspb02-fama-lan]="reset; fastfetch"
    [rspb03-fama-lan]="reset; fastfetch"
)

# Neustart
tmux kill-session -t "cluster_ssh_${1:-8}" 2>/dev/null
tmux new-session -d -s $SESSION

# Formate
tmux set-window-option -t $SESSION pane-border-status top
tmux set-window-option -t $SESSION pane-border-format " #T "

# --- DYNAMISCHER AUFBAU ---
# Wir berechnen,#Spalten
if [[ "$MODE" == "3" ]]; then
    # Nur 2 Splits für 3 Fenster nebeneinander
    tmux split-window -h -t $SESSION
    tmux split-window -h -t $SESSION
    tmux select-layout -t $SESSION even-horizontal
else
    # Für 6 oder 8: Erst die Hauptspalten
    # Bei 6 -> 3 Spalten, bei 8 -> 4 Spalten
    NUM_COLS=$(( ${#HOSTS} / 2 ))
    for i in {2..$NUM_COLS}; do
        tmux split-window -h -t $SESSION
    done
    tmux select-layout -t $SESSION even-horizontal
    
    # Jede Spalte einmal vertikal teilen
    PANES=($(tmux list-panes -t $SESSION -F '#D'))
    for p in $PANES; do
        tmux split-window -v -t $p
    done
fi

# Sortierung (Wichtig für die Zuweisung)
SORTED_PANES=($(tmux list-panes -t $SESSION -F '#{pane_top} #{pane_left} #D' | sort -n -k1,1 -k2,2 | awk '{print $3}'))

# SSH Commands senden
for i in {1..${#HOSTS}}; do
    PANE_ID=${SORTED_PANES[$i]}
    HOST=${HOSTS[$i]}
    CMD=${HOST_CMDS[$HOST]:-"clear"}
   
    [[ "$HOST" == "macmini-fama-lan" ]] && TMUX_BIN="/opt/homebrew/bin/tmux" || TMUX_BIN="tmux"

    PAYLOAD="tmux select-pane -t $PANE_ID -T '#[fg=black,bg=green,bold] $HOST #[default]'; ssh -t $HOST '$TMUX_BIN -f ~/.tmux.conf a || $TMUX_BIN -f ~/.tmux.conf new-session \"$CMD; exec zsh\"'; tmux select-pane -t $PANE_ID -T ' $HOST (Lokal) '"
    tmux send-keys -t $PANE_ID "$PAYLOAD" C-m
done

tmux select-pane -t ${SORTED_PANES[1]}
tmux attach-session -t $SESSION