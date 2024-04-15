#!/usr/bin/env bash

# Copyright © 2024 Jakub Wilk <jwilk@jwilk.net>
# SPDX-License-Identifier: MIT

set -e -u

. "${0%/*}/common.sh"

echo 1..3
xout=$(
    < "$dir/README" \
    grep '^   [$] ubanner --help$' -A999 |
    tail -n +2 |
    grep -B999 '^   [$]' |
    head -n -1 |
    sed -e 's/^   //'
)
out=$("$prog" --help)
out=${out/'TEXT [TEXT ...]'/TEXT ...}  # Python < 3.9 compat: https://bugs.python.org/issue38438
say() { printf "%s\n" "$@"; }
diff=$(diff -u <(say "$xout") <(say "$out")) || true
if [ -z "$diff" ]
then
    sed -e 's/^/# /' <<< "$out"
    echo 'ok 1'
else
    sed -e 's/^/# /' <<< "$diff"
    echo 'not ok 1'
fi
xsum=$(sha256sum <<< "$out")
xsum=${xsum%% *}
var='SHA-256(help)'
echo "# $var = $xsum"
declare -i n=2
t_sync()
{
    path="$1"
    line=$(grep -F " $var = " < "$dir/$path")
    sum=${line##*" $var = "}
    if [[ $sum = $xsum ]]
    then
        echo ok $n "$path"
    else
        echo not ok $n "$path"
    fi
    n+=1
}
t_sync 'completion/zsh/_ubanner'
t_sync 'doc/ubanner.1'

# vim:ts=4 sts=4 sw=4 et ft=sh
