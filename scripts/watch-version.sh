#!/bin/bash
while true; do
  r=$(curl -s -m 2 http://localhost:30080/version) || r="!!! ERROR (接続失敗) !!!"
  echo "$(date +%H:%M:%S)  $r"
  sleep 0.5
done
