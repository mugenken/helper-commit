use 5.006;
use strict;
use warnings;
use Module::Build;

my $builder = Module::Build->new(
    module_name         => 'Helper::Commit',
    license             => 'perl',
    dist_author         => q{Mugen Kenichi <mugen.kenichi@uninets.eu>},
    dist_version_from   => 'lib/Helper/Commit.pm',
    build_requires => {
        'Test::More' => 0,
    },
    requires => {
        'perl' => 5.006,
    },
    add_to_cleanup      => [ 'Helper-Commit-*' ],
    create_makefile_pl => 'traditional',
);

$builder->create_build_script();
