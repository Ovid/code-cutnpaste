#!/usr/bin/env perl
use lib 'lib';
use Code::CutNPaste;
use Test::Most;

{
    no warnings qw/redefine once/;
    *File::Temp::new = sub {
        die("Could not create temp file: Permission denied");
    }
}

ok my $cutnpaste = Code::CutNPaste->new(
    dirs         => 't/fixtures',
    renamed_vars => 1,
    renamed_subs => 1,
    noutf8       => 1,
);

$cutnpaste->find_dups;

done_testing();
