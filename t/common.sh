#!/usr/bin/env bash

# Copyright © 2024 Jakub Wilk <jwilk@jwilk.net>
# SPDX-License-Identifier: MIT

set -e -u

dir="${0%/*}/.."
prog="${UBANNER_TEST_TARGET:-"$dir/ubanner"}"

is_unicode_locale()
{
    local charset=$'\u2591\u2592\u2588'
    test ${#charset} -eq 3
}

# vim:ts=4 sts=4 sw=4 et ft=sh
