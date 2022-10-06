#!/bin/bash

workSession="work"
mySession="personal"

# directories
parkerhendocom="~/Developer/parkerhendocom"
dotfiles="~/dotfiles"

SESSIONEXISTS=$(tmux list-sessions | grep $workSession)

if [ "$SESSIONEXISTS" = "" ]
then
  tmux new-session -d -s $mySession

  # WORK SESSION
  tmux rename-window -t $mySession:1 -n 'personal-site'
  tmux send-keys -t $mySession:1 "cd ${parkerhendocom}" C-m
  tmux send-keys -t $mySession:1 "clear" C-m

  tmux new-window -t $mySession:2 -n 'dotfiles'
  tmux send-keys -t $mySession:2 "cd ${dotfiles}" C-m
  tmux send-keys -t $mySession:2 "clear" C-m
fi

tmux attach-session -t $mySession:1

