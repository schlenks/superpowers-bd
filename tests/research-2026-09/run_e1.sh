#!/usr/bin/env bash
# E1 full batch: sonnet on 4 fixtures, haiku on the 3 impossible fixtures.
cd "$(dirname "$0")"
for e in e1-eta-impossible e1-roman-impossible e1-tax-impossible e1-tax-control; do
  python3 harness.py "$e" -n 10 -j 3 > "logs/$e--sonnet.log" &
done
wait
for e in e1-eta-impossible e1-roman-impossible e1-tax-impossible; do
  python3 harness.py "$e" -n 10 -j 3 --model haiku > "logs/$e--haiku.log" &
done
wait
echo E1_DONE
