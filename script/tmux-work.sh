#!/bin/bash

session="work"

# directories
cloud="~/Developer/cloud-frontend"
materialize="~/Developer/materialize"
playground="~/Developer/mz-sql-playground"

SESSIONEXISTS=$(tmux list-sessions | grep $workSession)

if [ "$SESSIONEXISTS" = "" ]
then
  tmux new-session -d -s $session

  # WORK SESSION
  tmux rename-window -t $session:1 -n 'cloud'
  tmux send-keys -t $session:1 "cd ${cloud}" C-m
  tmux send-keys -t $session:1 "clear" C-m

  tmux new-window -t $session:2 -n 'materialize-core'
  tmux send-keys -t $session:2 "cd ${materialize}" C-m
  tmux send-keys -t $session:2 "clear" C-m

  tmux new-window -t $session:2 -n 'mz-sql-playground'
  tmux send-keys -t $session:2 "cd ${playground}" C-m
  tmux send-keys -t $session:2 "clear" C-m
fi

tmux attach-session -t $session:1

