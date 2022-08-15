#!/bin/bash

workSession="work"
mySession="personal"

# directories
hemingway="~/Developer/_Pallet/hemingway"
hegel="~/Developer/_Pallet/hegel"
huxley="~/Developer/_Pallet/huxley"
pps="~/Developer/_Pallet/prototype/pps"
parkerhendocom="~/Developer/parkerhendocom"
dotfiles="~/dotfiles"

SESSIONEXISTS=$(tmux list-sessions | grep $workSession)

if [ "$SESSIONEXISTS" = "" ]
then
  tmux new-session -d -s $workSession

  # WORK SESSION
  tmux rename-window -t $workSession:1 -n 'hemingway'
  tmux send-keys -t $workSession:1 "cd ${hemingway}" C-m
  tmux send-keys -t $workSession:1 "clear" C-m

  tmux new-window -t $workSession:2 -n 'hegel'
  tmux send-keys -t $workSession:2 "cd ${hegel}" C-m
  tmux send-keys -t $workSession:2 "clear" C-m

  tmux new-window -t $workSession:3 -n 'huxley'
  tmux send-keys -t $workSession:3 "cd ${huxley}" C-m
  tmux send-keys -t $workSession:3 "clear" C-m

  tmux new-window -t $workSession:4 -n 'prototyping'
  tmux send-keys -t $workSession:4 "cd ${pps}" C-m
  tmux send-keys -t $workSession:4 "clear" C-m


fi
tmux attach-session -t $workSession:1
# # PERSONAL SESSION

# window=1
# tmux rename-window -t $mySession:$window -n 'personal-site'
# tmux send-keys -t $mySession:$window "cd ${parkerhendocom}" C-m

# window=2
# tmux new-window -t $mySession:$window -n 'dotfiles'
# tmux send-keys -t $mySession:$window "cd ${dotfiles}" C-m

