#!/bin/bash -eux -o pipefail

PATH="$PATH:/opt/homebrew/bin"
export BUCKET=snap.philsnow.io
export AWS_VAULT_KEYCHAIN_NAME=login

function usage() {
  echo -e "usage:  $0 <path to screenshot directory> <destination path>"
}

if [ $# -ne 2 ]; then
  usage
  exit 1
fi

source_dir="$1"
dest_dir="$2"

function genslug() {
  LC_ALL=C </dev/urandom tr -dc a-z0-9 | head -c 20
}

function generate_new_file_name() {
  if [ $# -ne 1 ]; then
    echo "error, pass me a file name"
    exit 2
  fi

  local filename="$1"

  # BSD-specific stat args:
  local tyme=$(stat -n -t "%Y-%m-%dT%H-%M-%S" -f "%Sm" "$filename")
  local slug=$(genslug)
  local ext="${filename##*.}"

  echo "${tyme}.${slug}.${ext}"
}

find "$source_dir" -type f -print0 | while IFS= read -r -d '' file; do
  new_name=$(generate_new_file_name "$file")
  /usr/bin/time aws-vault exec snap -- aws s3 cp --no-progress "${file}" "s3://${BUCKET}/${new_name}"
  mv -f "${file}" "${dest_dir}/${new_name}"
done
