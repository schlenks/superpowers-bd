#!/usr/bin/env bash
# Opus coverage for the three adopted changes.
cd "$(dirname "$0")"
for e in e1-eta-impossible e1-roman-impossible e1-tax-impossible e1-tax-control; do
  python3 harness.py "$e" -n 10 -j 3 --model opus > "logs/$e--opus.log" &
done
wait
python3 harness.py e4-interface-note -n 20 -j 4 --model opus > logs/e4--opus.log &
python3 harness.py e4p-interface-report --arms B -n 5 -j 3 --model opus > logs/e4p--opus.log &
python3 harness.py e5-signup-clean --arms A,C -n 10 -j 3 --model opus > logs/e5-clean--opus.log &
python3 harness.py e5-signup-gaps --arms A,C -n 5 -j 2 --model opus > logs/e5-gaps--opus.log &
wait
echo OPUS_DONE
