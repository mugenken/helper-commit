use 5.010;
use strict;
use warnings;
use Module::Build;
use Getopt::Long;
use lib './lib';
use Helper::Commit::Version;

my $install = 0;
my $dist    = 0;
my $meta    = 0;
my $v       = Helper::Commit::Version->new;

GetOptions(
    'install' => \$install,
    'dist'    => \$dist,
    'meta'    => \$meta,
);

my $build = Module::Build->new(
    module_name       => 'Helper::Commit',
    license           => 'perl',
    dist_author       => q{Mugen Kenichi <mugen.kenichi@uninets.eu>},
    dist_version_from => 'lib/Helper/Commit/Version.pm',
    dist_abstract     => 'Helper to push modules to git repos and CPAN',

    build_requires     => { 'Module::Build' => 0.38, },
    configure_requires => { 'Module::Build' => 0.38, },
    requires           => {
        'perl'           => 5.012,
        'Moo'            => 0,
        'File::Find'     => 0,
        'File::Slurp'    => 0,
        'File::Copy'     => 0,
        'Perl::Tidy'     => 0,
        'Getopt::Long'   => 0,
        'CPAN::Uploader' => 0,
    },

    add_to_cleanup     => ['Helper-Commit-* Build _build MYMETA.*'],
    create_makefile_pl => 'traditional',

    meta_add => {
        no_index       => { directory => ['t'], },
        version        => $v->get,
        release_status => 'unstable',
    },

    meta_merge => {
        provides => {
            'Helper::Commit' => {
                file    => 'lib/Helper/Commit.pm',
                version => $v->get,
            },
            'Helper::Commit::Version' => {
                file    => 'lib/Helper/Commit/Version.pm',
                version => $v->get,
            },
        },
    },
);

if ($meta) {
    $build->dispatch('distmeta');
    exit 0;
}

if ($dist) {
    $build->dispatch('build');
    $build->dispatch('test');
    $build->dispatch('distmeta');
    $build->dispatch('dist');
    $build->create_build_script();
    exit 0;
}

if ($install) {
    $build->dispatch('build');
    $build->dispatch( 'test', verbose => 1 );
    $build->dispatch('install');
    $build->create_build_script();
    exit 0;
}

$build->create_build_script();

