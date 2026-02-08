#!/usr/bin/env bash
ip=$(ip route get 1.1.1.1 2>/dev/null | grep -oP 'src \K\S+')
echo "${ip:-Offline}"
