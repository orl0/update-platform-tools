#!/usr/bin/env bash
# shellcheck shell=bash
# shellcheck disable=SC2155
#
# This script gets the latest available version of Android SDK Platform Tools,
# checks local version and updates it if needed.
#
# No options available.
#
# Place this script in the directory with Platform Tools.
#
# You can override download link using the environment variable:
# SDK_PT_LATEST_DL_LINK='https://some.url' ./update.sh
#
# Official Android SDK Platform Tools site:
# https://developer.android.com/studio/releases/platform-tools
#
#  The MIT License (MIT)
#
#  Copyright (c) 2021 Roman Orlovsky (https://orl0.github.io/)
#
#  Permission is hereby granted, free of charge, to any person obtaining a copy
#  of this script (the "Software"), to deal in the Software without restriction,
#  including without limitation the rights to use, copy, modify, merge, publish,
#  distribute, sublicense, and/or sell copies of the Software, and to permit
#  persons to whom the Software is furnished to do so, subject to the following
#  conditions:
#
#  The above copyright notice and this permission notice (including the next
#  paragraph) shall be included in all copies or substantial portions of
#  the Software.
#
#  THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
#  IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
#  FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL
#  THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
#  LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
#  OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
#  THE SOFTWARE.

# Debug mode:
# set -o xtrace

# Setting some options:
# - Exit on error
# - Do not allow use of undefined vars (on version 4.4+).
# - Set the exit code of a pipeline to zero or to the rightmost exit code
if test "$BASH" = "" || "$BASH" -uc "a=();true \"\${a[@]}\"" 2>/dev/null; then
    set -euo pipefail
else
    # Bash 4.3 and older chokes on empty arrays with set -u.
    set -eo pipefail
fi

# URL to latest platform tools.
# Could be overriden or uses default value.
readonly SDK_PT_LATEST_DL_LINK=${SDK_PT_LATEST_DL_LINK:-'https://dl.google.com/android/repository/platform-tools-latest-linux.zip'}

# Some usefull variables
readonly __base="$(basename "${BASH_SOURCE[0]}")"
# And functions
function installed() { [[ $(type -p "${1?}") ]]; }
function err() { echo "${__base}: $*" >&2; }
function normalize_version() {
  command awk 'BEGIN {
    split(ARGV[1], x, /\-/);
    split(x[1], a, /\./);
    printf "%d%06d%06d\n", a[1], a[2], a[3];
    exit;
  }' "${1#r}"
}

# Mark for commands in console log
readonly pre="=> "

# Main loop
function main() {
  if ! installed "curl"; then
    err "'curl' is required for this script to work"
    err "please install it with your package manager and try again"
    exit 1
  fi
  if ! installed "unzip"; then
    err "'unzip' is required for this script to work"
    err "please install it with your package manager and try again"
    exit 1
  fi

  if ! [[ -x ./fastboot ]]; then
    err "can't find or execute 'fastboot' in current directory"
    exit 1
  fi

  local local_version local_norm_ver remote_version remote_norm_ver
  local_version=$(./fastboot --version | head -1 | rev | cut -d' ' -f1 | rev)

  local -r remote_latest_file=$(
                          curl -qsSI "${SDK_PT_LATEST_DL_LINK}" \
                          | grep -iE "location\: " | rev | cut -d/ -f1 | rev)
  remote_version=$(echo "$remote_latest_file" | cut -d'_' -f2 | cut -d'-' -f1)

  local_norm_ver=$(normalize_version "${local_version}")
  remote_norm_ver=$(normalize_version "${remote_version}")

  if [[ local_norm_ver -lt remote_norm_ver ]]; then
    echo "Newer version found!"
    echo
    echo "!!! THIS SCRIPT IS PROVIDED 'AS IS' AND WITHOUT WARRANTY OF ANY KIND"
    echo
    echo "You sould read and accept the terms and conditions for Android SDK"
    echo "(This is not legal advice! Ask a professional if unsure)"
    echo
    echo "You can find it here: <https://developer.android.com/studio/terms>"
    echo
    echo "Local version:   ${local_version}"
    echo "Remote version:  ${remote_version}"
    echo ""
    printf "Do you want to perform upgrade? [Y/n] "
    read -r Y_OR_N REST && Y_OR_N=${Y_OR_N:-y}
    if [[ ${Y_OR_N,,} == 'y' ]]; then
      echo

      if ! installed "unzip"; then
        err "you need 'unzip' utility to perform upgrade"
        err "please install it with your package manager and try again"
        exit 1
      fi
      if ! [[ -w "$PWD" ]]; then
        err "you don't have permission to write into this directory"
        err "no actions have been performed"
        exit 1
      fi

      local tmp_dir tmp_fn
      tmp_dir=$(mktemp -d -t update_pt.XXXXXXXXXX)
      tmp_fn=$(echo "${SDK_PT_LATEST_DL_LINK}" | rev | cut -d/ -f1 | rev)

      echo "${pre}Dowloading '${tmp_fn}'..."
      echo ""
      curl -q -L -o "${tmp_dir}/${tmp_fn}" "${SDK_PT_LATEST_DL_LINK}"

      local -r curl_return_code=$?
      if [[ $curl_return_code = 0 ]]; then
        echo ""
        echo "${pre}Using unzip to extract '${tmp_fn}':"
        echo ""
        unzip -qo "${tmp_dir}/${tmp_fn}" "platform-tools/*" -d "${tmp_dir}"

        local -r unzip_return_code=$?
        if [[ $unzip_return_code = 0 ]]; then
          echo "."
          echo "??? Done!"
          echo ""
          echo "${pre}Coping extracted files to '${PWD}'..."
          echo ""
          cp -rfu -t "${PWD}" "${tmp_dir}/platform-tools/"*
          local -r cp_return_code=$?
          if [[ $cp_return_code = 0 ]]; then
            echo "."
            echo "??? Successful!"
            echo ""
          else
            err "cp exited with code '$cp_return_code'"
          fi
        else
          err "unzip exited with code '$unzip_return_code'"
        fi
      else
        err "curl exited with code '$curl_return_code'"
      fi

      echo "${pre}Cleaning up..."
      rm -rf "$tmp_dir" && echo "Done!"
    else
      echo "Aborted."
    fi
  fi

  local -r return_code=$?
  return ${return_code}
}


# Function packaging!
#  - source this file and use it as a function in your script
# Idea was taken from http://bash3boilerplate.sh/
if [[ "${BASH_SOURCE[0]}" != "$0" ]]; then
  # Rename 'main' function...
  readonly f=$(declare -f "${__base}")
  eval "function ${__base} ${f#*"()"}"
  unset f; unset -f "main"
  # ...and export it with the same name as script have
  export -f "${__base?}"
else
  main
  exit $?
fi

