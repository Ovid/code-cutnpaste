use 5.006;
use strict;
use warnings;
use Module::Build;

my $builder = Module::Build->new(
    module_name         => 'Code::CutNPaste',
    license             => 'perl',
    dist_author         => q{Curtis "Ovid" Poe <ovid@cpan.org>},
    dist_version_from   => 'lib/Code/CutNPaste.pm',
    build_requires => {
        'Test::More' => 0,
    },
    requires => {
        'perl' => 5.006,
    },
    add_to_cleanup      => [ 'Code-CutNPaste-*' ],
    create_makefile_pl => 'traditional',
);

$builder->create_build_script();
