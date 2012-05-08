package Helper::Commit;

use 5.010;
use feature 'say';
use strict;
use warnings;
use autodie;
use lib './lib';
use Moo;
use Term::ANSIColor;
use Perl::Tidy;
use File::Find;
use File::Copy;
use File::Slurp 'edit_file';
use Getopt::Long;
use CPAN::Uploader;

has git          => ( is => 'rw' );
has cpan         => ( is => 'rw' );
has cpan_user    => ( is => 'rw' );
has _debug       => ( is => 'rw' );
has _new_version => ( is => 'rw' );

sub BUILD {
    my ($self) = @_;

    $self->git(1) if $self->cpan;

}

sub run {
    my ($self) = @_;

    $self->_run_default;
    $self->_run_git  if $self->git;
    $self->_run_cpan if $self->cpan;

    return 1;
}

sub _say_ok {
    my ( $self, $line ) = @_;
    chomp $line;

    if ( not $self->_debug ) {
        print color 'green';
        print '  > ';
        print color 'reset';
    }
    print "$line\n";

    return 1;
}

sub _say_warn {
    my ( $self, $line ) = @_;
    chomp $line;

    if ( not $self->_debug ) {
        print color 'yellow';
        print ' >> ';
        print color 'reset';
    }
    print "$line\n";

    return 1;
}

sub _say_err {
    my ( $self, $line ) = @_;
    chomp $line;

    if ( not $self->_debug ) {
        print color 'red';
        print ' >> ';
        print color 'reset';
    }
    print "$line\n";

    return 1;
}

sub _say_prompt {
    my ($self) = @_;

    if ( not $self->_debug ) {
        print color 'blue';
        print '>>> ';
        print color 'reset';
    }

    return 1;
}

sub _bump_version {
    my ($self) = @_;
    my $old_version = qx[awk '/^Version/ {print \$2}' \$(find lib/ -name Version.pm)];
    chomp $old_version;

    my $module = qx[awk '/^package/ {print \$2}' \$(find lib/ -name Version.pm)];
    ( $module = $module ) =~ s/;//;
    chomp $module;

    eval "require $module";
    my $version = $module->get;

    my @files = qx[grep $old_version -l \$(find -iname *.p?)];

    if ( $old_version != $version ) {
        for (@files) {
            chomp;
            edit_file {s/$old_version/$version/g} $_;
        }

        $self->_new_version(1);
        $self->_say_ok("bumped version from $old_version to $version");

    }
    elsif ( $self->cpan ) {
        $self->_say_err("No version update. Unable to upload to CPAN");
        $self->cpan(0);
    }
    else {
        $self->_say_warn("No version update.");
    }

    return 1;
}

sub _build_meta {
    my ($self) = @_;
    my $result = qx[perl Build.PL --meta];
    $self->_say_ok('Updating META');
}

sub _build_clean {
    my ($self) = @_;
    if ( -f 'Build' && -x 'Build' ) {
        my $result = qx[./Build clean];
        $self->_say_warn('cleaned up');
        say $result if $self->_debug;
    }
    else {
        $self->_say_ok('no need to clean');
    }

    return 1;
}

sub _git_add_new_files {
    my ($self) = @_;
    my @status = qx[git status];

    for (@status) {
        if (/.+new file:\s*(.*)/) {
            $self->_say_warn("adding $1");
            my $result = qx[git add $1];
            say $result if $self->_debug;
        }
    }

    return 1;
}

sub _git_commit {
    my ($self)    = @_;
    my @status    = qx[git status];
    my $no_commit = 0;
    $no_commit = grep { $_ ~~ /nothing to commit/ } @status;

    if ($no_commit) {
        $self->_say_ok('nothing to commit');
    }
    else {
        $self->_say_ok('git status:');
        $self->_say_warn($_) for @status;
        $self->_say_err('enter commit message [finish with "."]');
        $self->_say_prompt;

        my $message = '';
        while (<>) {
            last if /^.\n/;
            $message .= $_;
        }

        say $message if $self->_debug;

        if ($message) {
            $self->_say_ok('commiting to git repo');
            my $result = qx[git commit -a -m '$message'];

            say $result if $self->_debug;
        }
        else {
            $self->$self->_say_err('Canceled due to missing commit message.');

            exit 1;
        }
    }

    return 1;
}

sub _git_push {
    my ($self) = @_;
    my $result = qx[git push 2>&1];

    if ( $result ~~ /Everything up-to-date/ ) {
        $self->_say_ok('Everything up-to-date.');

    }
    else {
        $self->_say_ok('Pushed to git repo');
    }

    say $result if $self->_debug;

    return 1;
}

sub _tidy_up {
    my ($self) = @_;
    my @files;

    find(
        sub {
            push( @files, $File::Find::name ) if ( /\.p[lm]$/i && !-d );
        },
        '.'
    );

    for (@files) {
        $self->_say_ok("Tidy up $_");
        my $destination = "$_._tidy_up";
        Perl::Tidy::perltidy(
            source      => $_,
            destination => $destination,
            perltidyrc  => 'files/perltidyrc',
        );
        move "$_._tidy_up", $_;
    }

    return 1;
}

sub _build_dist {
    my ($self) = @_;
    my $result = system 'perl Build.PL --dist 2>&1 > /dev/null';

    if ($result) {
        $self->_say_err('Failed to build dist. Refusing to go on.');
        exit 1;
    }

    $self->_say_ok('Built dist');
}

sub _cpan_upload {
    my ($self) = @_;

    my $module = qx[awk '/^package/ {print \$2}' \$(find lib/ -name Version.pm)];
    ( $module = $module ) =~ s/;//;
    chomp $module;

    eval "require $module";
    my $version = $module->get;

    my ($file) = grep { -f && !-d && /$version/ } glob '*.tar.gz';

    $self->_say_err('PAUSE password (will not echo):');
    $self->_say_prompt;

    my $pass;
    system 'stty -echo';
    while (<>) {
        $pass = $_;
        last if /\n/;
    }
    system 'stty echo';
    chomp $pass;

    my $uploader = CPAN::Uploader->new( { user => $self->cpan_user, password => $pass } );

    $uploader->upload_file($file);

    $self->_say_ok('Uploaded to cpan!');
}

sub _run_git {
    my ($self) = @_;

    $self->_git_add_new_files;
    $self->_git_commit;
    $self->_git_push;

    return 1;
}

sub _run_cpan {
    my ($self) = @_;

    $self->_build_dist;
    $self->_cpan_upload;

    return 1;
}

sub _run_default {
    my ($self) = @_;

    $self->_build_clean;
    $self->_build_meta;
    $self->_tidy_up;
    $self->_bump_version;

    return 1;
}

1;

__END__

=head1 NAME

Helper::Commit

=head1 WARNING!

This is an unstable development release not ready for production!

=head1 VERSION

Version 0.000001

=head1 SYNOPSIS

Helper::Commit is a module to help simplifying the process of using both git and CPAN in perl module development.
To work properly your module will have to have a Version.pm that will be used to determine version changes and to update the version information in the perldoc and the other modules.
Drawback of this is all files of the module will have the same version information.

=head1 ATTRIBUTES

=head2 git

True or false.

=head2 cpan

True or false.

=head2 cpan_user

Username of your PAUSE account

=head1 METHODS

=head2 new

    my $commit_helper = Helper::Commit->new(
        git       => 0, # true if you want git commit and push
        cpan      => 0, # true if you want to upload to CPAN (will set git true!)
        cpan_user => 'mugenken',
    );

=head2 run

    $commit_helper->run;

=head1 AUTHOR

Mugen Kenichi, C<< <mugen.kenichi at uninets.eu> >>

=head1 BUGS

Report bugs at:

=over 2

=item * Unicorn::Manager issue tracker

L<https://github.com/mugenken/p5-Ruby-VersionManager/issues>

=item * support at uninets.eu

C<< <mugen.kenichi at uninets.eu> >>

=back

=head1 SUPPORT

=over 2

=item * Technical support

C<< <mugen.kenichi at uninets.eu> >>

=back

=cut

