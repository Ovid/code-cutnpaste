#!/usr/bin/env perl
use lib 'lib';
use Code::CutNPaste;
use Test::Most;

my $error = 'Could not create temp file: Permission denied';
$SIG{__WARN__} = sub { warn $_[0] unless $_[0] =~ /$error/ };
no warnings qw/redefine once/;
*File::Temp::new = sub { die($error); };

ok my $cutnpaste = Code::CutNPaste->new(
    dirs         => 't/fixtures',
    renamed_vars => 1,
    renamed_subs => 1,
    noutf8       => 1,
);

$cutnpaste->find_dups;

done_testing();
