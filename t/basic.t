#!/usr/bin/env perl

use lib 'lib';
use Code::CutNPaste;
use Test::Most;

ok my $cutnpaste = Code::CutNPaste->new(
    dirs         => 't/fixtures',
    renamed_vars => 1,
    renamed_subs => 1,
    verbose      => 1,
);
$cutnpaste->find_dups;
show $cutnpaste->duplicates;
done_testing;
