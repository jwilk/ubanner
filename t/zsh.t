#!/usr/bin/env perl

# Copyright © 2024 Jakub Wilk <jwilk@jwilk.net>
# SPDX-License-Identifier: MIT

no lib '.';  # CVE-2016-1238

use strict;
use warnings;
use v5.14;

use Data::Dumper ();
use English qw(-no_match_vars);
use File::Temp 0.23 ();
use FindBin ();
use Time::HiRes qw(clock_gettime CLOCK_MONOTONIC);
use Test::More;
use autodie qw(open close);

my $target_env_var = 'UBANNER_TEST_TARGET';
eval {
    require IO::Pty::Easy;
    IO::Pty->import(1.11);
    1;
} or do {
    plan skip_all => "$EVAL_ERROR";
};
if (defined $ENV{$target_env_var}) {
    plan skip_all => "\$$target_env_var is not supported yet";
}
do {
    my $zsh_err = qx(zsh --version 2>&1 >/dev/null);
    if ($CHILD_ERROR != 0) {
        my $msg = 'zsh is unavailable';
        if ($zsh_err ne '') {
            $msg = "$msg: $zsh_err";
        }
        plan skip_all => $msg;
    }
};
plan tests => 4;

my $basedir = "$FindBin::Bin/..";
my $tmpdir = File::Temp->newdir(
    TEMPLATE => 'ubanner.test.XXXXXX',
    TMPDIR => 1,
);
open my $fh, '>', "$tmpdir/.zshrc";
print {$fh} <<'EOF' or die $ERRNO;
path+=($UBANNER_DIR)
fpath+=($UBANNER_DIR/completion/zsh)
autoload -Uz compinit
compinit
EOF
close $fh;
my $pty = IO::Pty::Easy->new;
my $prompt = 'ubanner-test%';
do {
    local $ENV{TERM} = 'ansi';
    local $ENV{ZDOTDIR} = $tmpdir;
    local $ENV{UBANNER_DIR} = $basedir;
    local $ENV{PS1} = $prompt =~ s/%/%%/gr;
    $pty->spawn('zsh', '-i');
};

sub squash_ansi
{
    (local $_) = @_;
    s/\e\[.*?[a-zA-Z]//g;
    s/\r/\n/g;
    return $_;
}

sub gettime
{
    return clock_gettime(CLOCK_MONOTONIC);
}

sub expect
{
    my ($regexp) = @_;
    my $status;
    my $output = '';
    my $timeout = 10;
    my $start_time = gettime();
    while (1) {
        my $chunk = $pty->read(1);
        if (defined $chunk) {
            if ($chunk eq '') {
                $status = 'EOF';
                last;
            }
            $output .= $chunk;
        }
        if (defined $chunk and squash_ansi($output) =~ $regexp) {
            $status = 'OK';
            last;
        }
        if (gettime() - $start_time > $timeout) {
            $status = 'timeout';
            last;
        }
    }
    return ($status, $output);
}

sub xnote
{
    my ($s) = @_;
    my @s = split /(?<=\n)/, $s;
    for (@s) {
        $_ = Data::Dumper::qquote($_);
        s/\A"// and s/"\z//;
        note($_);
    }
    return;
}

$pty->set_winsize(24, 80);
my ($status, $output) = expect(qr/^\Q$prompt\E/m);
xnote($output);
cmp_ok($status, 'eq', 'OK', 'prompt');
my $input = "ubanner -\t";
my $n = $pty->write($input);
cmp_ok($n, '==', length($input), 'input');
($status, $output) = expect(qr/^--version /m);
xnote($output);
cmp_ok($status, 'eq', 'OK', 'found options');
open $fh, '<', "$basedir/README";
my $readme;
{
    local $RS = undef;
    $readme = <$fh>;
}
close $fh;
$readme =~ /\n +options:\n((?:.+\n)+)/ or die;
my $help_options = $1;
my @help_options = $help_options =~ m/\s(-[\w-]+)/g;
@help_options = sort @help_options;
my @cmpl_options = squash_ansi($output) =~ m/\s(--?\w[\w-]*)/g;
@cmpl_options = sort @cmpl_options;
cmp_ok("@cmpl_options", 'eq', "@help_options", 'option list');
$pty->close;

# vim:ts=4 sts=4 sw=4 et
