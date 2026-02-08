#!/usr/bin/env bash
start_date="2025-05-12"
start_ts=$(date -d "$start_date" +%s)
now_ts=$(date +%s)
diff=$(( (now_ts - start_ts) / 86400 ))
echo "${diff} days since 2025-05-12"
