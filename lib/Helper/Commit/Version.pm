package Helper::Commit::Version;

use strict;
use warnings;
use version;

sub new {
    my $class = shift;
    my $self  = {};
    return bless $self, $class;
}

sub get {
    my $self    = shift;
    my $VERSION = version->declare('0.00.04')->numify;
    return $VERSION;
}

1;

__END__

=head1 NAME

Helper::Commit::Version

=head1 WARNING!

This is an unstable development release not ready for production!

=head1 VERSION

Version 0.000004

=head1 SYNOPSIS

Helper::Commit::Version is uses to declare the Helper::Commit version.

=head1 METHODS

=head2 new

    my $commit_helper = Helper::Commit::Version->new;

=head2 get

Used to get the current version of Helper::Commit

    my $version = $commit_helper->get;

Or

    my $version = Helper::Commit::Version->get;

=head1 AUTHOR

Mugen Kenichi, C<< <mugen.kenichi at uninets.eu> >>

=head1 BUGS

Report bugs at:

=over 2

=item * Helper::Commit issue tracker

L<https://github.com/mugenken/helper-commit/issues>

=item * support at uninets.eu

C<< <mugen.kenichi at uninets.eu> >>

=back

=head1 SUPPORT

=over 2

=item * Technical support

C<< <mugen.kenichi at uninets.eu> >>

=back

=cut


