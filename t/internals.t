#!/usr/bin/env perl

use lib 'lib';
use Code::CutNPaste;
use Test::Most;

ok my $cutnpaste = Code::CutNPaste->new(
    dirs         => 't/fixtures',
    renamed_vars => 1,
    renamed_subs => 1,
);

my $code = [
  {
    'code' => '            if ($k) {',
    'key' => 'if($XXX){',
    'line' => '4'
  },
  {
    'code' => '                my $null = $i + $j + $k;',
    'key' => 'my$XXX=$XXX+$XXX+$XXX;',
    'line' => '5'
  },
  {
    'code' => '            }',
    'key' => '}',
    'line' => '6'
  },
  {
    'code' => '        }',
    'key' => '}',
    'line' => '7'
  },
  {
    'code' => '    }',
    'key' => '}',
    'line' => '8'
  },
  {
    'code' => '}',
    'key' => '}',
    'line' => '9'
  },
];

ok $cutnpaste->_match_below_threshold( 6, $code ),
  'Code with too many non-word lines should not pass our threshold';

$code = [
  {
    'code' => '            if ($k) {',
    'key' => 'if($XXX){',
    'line' => '4'
  },
  {
    'code' => '                my $null = $i + $j + $k;',
    'key' => 'my$XXX=$XXX+$XXX+$XXX;',
    'line' => '5'
  },
  {
    'code' => '                $null++;',
    'key' => '$XXX++',
    'line' => '6'
  },
  {
    'code' => '                $i++;',
    'key' => '$XXX++',
    'line' => '7'
  },
  {
    'code' => '    }',
    'key' => '}',
    'line' => '8'
  },
];

ok !$cutnpaste->_match_below_threshold( 4, $code ),
  'Code with enough word lines should pass our threshold';

done_testing;
