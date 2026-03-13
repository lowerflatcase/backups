#!/usr/bin/env bash
set -e
BASE="https://raw.githubusercontent.com/lowerflatcase/backups/main"
bash <(curl -fsSL "$BASE/scripts/${1#--}.sh")