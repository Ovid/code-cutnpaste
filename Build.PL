use 5.006;
use strict;
use warnings;
use Module::Build;

my $builder = Module::Build->new(
    module_name       => 'Code::CutNPaste',
    license           => 'perl',
    dist_author       => q{Curtis "Ovid" Poe <ovid@cpan.org>},
    dist_version_from => 'lib/Code/CutNPaste.pm',
    build_requires    => {
        'Test::Most' => '0.25',
    },
    requires => {
        'Capture::Tiny'    => '0.17',
        'File::Find::Rule' => '0.33',
        'File::HomeDir'    => 0,
        'File::Slurp'      => '9999.19',
        'Moo'              => 0,
        'autodie'          => '2.10',
        'perl'             => 5.006,
        'utf8::all'        => '0.004',
    },
    add_to_cleanup     => ['Code-CutNPaste-*'],
    create_makefile_pl => 'traditional',
);

$builder->create_build_script();
