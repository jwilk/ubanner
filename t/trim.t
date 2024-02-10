#!/usr/bin/env bash

# Copyright © 2024 Jakub Wilk <jwilk@jwilk.net>
# SPDX-License-Identifier: MIT

set -e -u

. "${0%/*}/common.sh"

echo 1..1
is_unicode_locale || {
    echo 'non-Unicode locale' >&2
    exit 1
}
if out=$("$prog" --trim $'\u10E3')
then
    sed -e 's/^/# /' <<< "$out"
    echo ok 1
else
    echo not ok 1
fi

# vim:ts=4 sts=4 sw=4 et ft=sh
