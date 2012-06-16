package GrindTest;

use strict;
use warnings;

use base 'TestBase';

use Test::More;
use Test::Fatal;
use Test::Differences;

use App::Podgrind;

sub create_pod : Test {
    my $self = shift;

    my $grind = $self->_build_grind;

    my $input = <<'EOF';
package Foo;

sub new {}
sub method {}
sub _private {}

1;
EOF

    my $output = '';
    $grind->process(input => \$input, output => \$output);

    eq_or_diff($output, <<'EOF');
package Foo;

sub new {}
sub method {}
sub _private {}

1;
__END__
=pod

=head1 NAME

Foo - Module

=head1 METHODS

=head2 C<new>

=head2 C<method>

=head1 AUTHOR

Foo, C<foo@bar.com>

=head1 COPYRIGHT AND LICENSE

Copyright (C) 2012, Foo.

This module is free software; you can redistribute it and/or modify it under the
same terms as Perl 5.10.0. For more details, see the full text of the licenses
in the directory LICENSES.

This program is distributed in the hope that it will be useful, but without any
warranty; without even the implied warranty of merchantability or fitness for
a particular purpose.

=cut
EOF
}

sub update_pod_methods : Test {
    my $self = shift;

    my $grind = $self->_build_grind;

    my $input = <<'EOF';
package Foo;

sub new {}
sub method {}
sub method2 {}
sub _private {}

1;
__END__
=pod

=head1 NAME

Foo - Module

=head1 METHODS

=head2 C<new>

=head2 C<method>

Old description

=head2 C<removed>

=cut
EOF

    my $output = '';
    $grind->process(input => \$input, output => \$output);

    my ($methods) = $output =~ m/(=head1 METHODS.*?)=head1/ms;

    eq_or_diff($methods, <<'EOF');
=head1 METHODS

=head2 C<new>

=head2 C<method>

Old description

=head2 C<method2>

EOF
}

sub _build_grind {
    my $self = shift;

    return App::Podgrind->new(
        config => {author => 'Foo', email => 'foo@bar.com'},
        @_
    );
}

1;
