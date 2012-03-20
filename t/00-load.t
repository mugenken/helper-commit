#!perl -T

use Test::More tests => 1;

BEGIN {
    use_ok( 'Helper::Commit' ) || print "Bail out!\n";
}

diag( "Testing Helper::Commit $Helper::Commit::VERSION, Perl $], $^X" );
