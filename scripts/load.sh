#!/bin/bash
DURATION=${1:-180}
for i in $(seq 1 20); do
  timeout "$DURATION" bash -c 'while true; do curl -s -m 30 http://localhost:30080/heavy > /dev/null; done' &
done
wait
