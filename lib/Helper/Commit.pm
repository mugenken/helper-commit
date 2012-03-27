package Helper::Commit;

use 5.010;
use feature 'say';
use strict;
use warnings;
use autodie;
use lib 'lib';
use Moo;
use Unicorn::Manager::Version;
use Term::ANSIColor;
use Perl::Tidy;
use File::Find;
use File::Copy;
use File::Slurp 'edit_file';
use Getopt::Long;
use CPAN::Uploader;

has git          => ( is => 'rw' );
has cpan         => ( is => 'ro' );
has debug        => ( is => 'ro' );
has _new_version => ( is => 'rw' );

sub BUILD {
    my ($self) = @_;

    $self->git(1) if $self->cpan;

}

sub run {
    my ($self) = @_;

    $self->run_default;
    $self->run_git  if $self->git;
    $self->run_cpan if $self->cpan;

    return 1;
}

sub say_ok {
    my ( $self, $line ) = @_;
    chomp $line;

    if ( not $self->debug ) {
        print color 'green';
        print '  > ';
        print color 'reset';
    }
    print "$line\n";

    return 1;
}

sub say_warn {
    my ( $self, $line ) = @_;
    chomp $line;

    if ( not $self->debug ) {
        print color 'yellow';
        print ' >> ';
        print color 'reset';
    }
    print "$line\n";

    return 1;
}

sub say_err {
    my ( $self, $line ) = @_;
    chomp $line;

    if ( not $self->debug ) {
        print color 'red';
        print ' >> ';
        print color 'reset';
    }
    print "$line\n";

    return 1;
}

sub say_prompt {
    my ($self) = @_;

    if ( not $self->debug ) {
        print color 'blue';
        print '>>> ';
        print color 'reset';
    }

    return 1;
}

sub bump_version {
    my ($self) = @_;
    my $old_version = qx[awk '/^Version/ {print \$2}' \$(find lib/ -name Version.pm)];
    chomp $old_version;

    my $version = Unicorn::Manager::Version->get;

    my @files = qx[grep $old_version -l \$(find -iname *.p?)];

    if ( $old_version != $version ) {
        for (@files) {
            chomp;
            edit_file {s/$old_version/$version/g} $_;
        }

        $self->_new_version(1);
        $self->say_ok("bumped version from $old_version to $version");

    }
    elsif ( $self->cpan ) {
        $self->say_err ("No version update. Unable to upload to CPAN");
    }
    else {
        $self->say_warn("No version update.");
    }

    return 1;
}

sub build_meta {
    my ($self) = @_;
    my $result = qx[perl Build.PL --meta];
    $self->say_ok('Updating META');
}

sub build_clean {
    my ($self) = @_;
    if ( -f 'Build' && -x 'Build' ) {
        my $result = qx[./Build clean];
        $self->say_warn('cleaned up');
        say $result if $self->debug;
    }
    else {
        $self->say_ok('no need to clean');
    }

    return 1;
}

sub git_add_new_files {
    my ($self) = @_;
    my @status = qx[git status];

    for (@status) {
        if (/.+new file:\s*(.*)/) {
            $self->say_warn("adding $1");
            my $result = qx[git add $1];
            say $result if $self->debug;
        }
    }

    return 1;
}

sub git_commit {
    my ($self) = @_;
    my @status = qx[git status];
    my $no_commit = grep { $_ ~~ /nothing to commit/ } @status;

    if ($no_commit) {
        $self->say_ok('nothing to commit');
    }
    else {
        $self->say_ok('git status:');
        $self->say_warn($_) for @status;
        $self->say_err ('enter commit message [finish with "."]');
        say_prompt;

        my $message = '';
        while (<>) {
            last if /^.\n/;
            $message .= $_;
        }

        say $message if $self->debug;

        if ($message) {
            $self->say_ok('commiting to git repo');
            my $result = qx[git commit -a -m '$message'];

            say $result if $self->debug;
        }
        else {
            $self->$self->say_err('Canceled due to missing commit message.');

            exit 1;
        }
    }

    return 1;
}

sub git_push {
    my ($self) = @_;
    my $result = qx[git push 2>&1];

    if ( $result ~~ /Everything up-to-date/ ) {
        $self->say_ok('Everything up-to-date.');

    }
    else {
        $self->say_ok('Pushed to git repo');
    }

    say $result if $self->debug;

    return 1;
}

sub tidy_up {
    my ($self) = @_;
    my @files;

    find(
        sub {
            push( @files, $File::Find::name ) if ( /\.p[lm]$/i && !-d );
        },
        '.'
    );

    for (@files) {
        $self->say_ok("Tidy up $_");
        my $destination = "$_.tidy_up";
        Perl::Tidy::perltidy(
            source      => $_,
            destination => $destination,
            perltidyrc  => 'files/perltidyrc',
        );
        move "$_.tidy_up", $_;
    }

    return 1;
}

sub build_dist {
    my ($self) = @_;
    my $result = system 'perl Build.PL --dist 2>&1 > /dev/null';

    if ($result) {
        $self->say_err ('Failed to build dist. Refusing to go on.');
        exit 1;
    }

    $self->say_ok('Built dist');
}

sub cpan_upload {
    my ($self) = @_;

    my $version = Unicorn::Manager::Version->get;
    my ($file) = grep { -f && !-d && /$version/ } glob '*.tar.gz';

    $self->say_err ('PAUSE password (will not echo):');
    say_prompt;

    my $pass;
    system 'stty -echo';
    while (<>) {
        $pass = $_;
        last if /\n/;
    }
    system 'stty echo';
    chomp $pass;

    my $uploader = CPAN::Uploader->new( { user => 'mugenken', password => $pass } );

    $uploader->upload_file($file);

    $self->say_ok('Uploaded to cpan!');
}

sub run_git {
    my ($self) = @_;

    $self->git_add_new_files;
    $self->git_commit;
    $self->git_push;

    return 1;
}

sub run_cpan {
    my ($self) = @_;

    $self->build_dist;
    $self->cpan_upload;

    return 1;
}

sub run_default {
    my ($self) = @_;

    $self->build_clean;
    $self->build_meta;
    $self->tidy_up;
    $self->bump_version;

    return 1;
}

1;

__END__

