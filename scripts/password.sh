#!/bin/sh

set -eu

generate_password() {
  password_length=$1

  password=$(tr -dc 'A-Za-z0-9!@#$%^&*()-_=+' </dev/urandom | head -c "$password_length")

  echo "$password"
}

password_length=12
num_passwords=1

while getopts "l:n:" opt; do
  case $opt in
    l) password_length=$OPTARG ;;
    n) num_passwords=$OPTARG ;;
    *) echo "Usage: $0 [-l length] [-n num_passwords]" >&2; exit 1 ;;
  esac
done


if [ "$password_length" -lt 1 ]; then
  echo "Password length must be at least 1." >&2
  exit 1
fi


if [ "$num_passwords" -lt 1 ]; then
  echo "Number of passwords must be at least 1." >&2
  exit 1
fi

i=1
while [ $i -le "$num_passwords" ]; do
  generate_password "$password_length"
  i=$((i+1))
done
