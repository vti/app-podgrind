use strict;
use warnings;

use Test::More;

use lib 't/perl_parser_t';

use App::Podgrind::PerlParser;

subtest 'parses package' => sub {
    my $parser = _build_parser()->parse(\<<'EOF');
package Foo;
use base 'ParentClass';
sub new {
    my $class = shift;

    return $self;
}

# This is a commented method
# multiline
sub bar {
    my $self = shift;
    my ($foo, $bar) = @_;
}

sub baz {
    my ($self, $one) = @_;
}

sub _private {
}

sub DESTROY {}
sub AUTOLOAD {}

1;
__END__
=pod

=head1 NAME

Foo - is foo
=cut
EOF

    my $name = $parser->get_package_name;
    is_deeply $name, 'Foo';

    my $isa = $parser->get_isa;
    is_deeply $isa, ['ParentClass'];

    my $inherited_methods = $parser->get_inherited_methods;
    is_deeply $inherited_methods,
      [{name => 'inherited', argv => [], comment => ''}];

    my $methods = $parser->get_public_methods;
    is_deeply $methods,
      [
        {name => 'new', argv => [], comment => ''},
        {
            name    => 'bar',
            argv    => [qw/$foo $bar/],
            comment => 'This is a commented method multiline'
        },
        {name => 'baz', argv => [qw/$one/], comment => ''},
      ];

    my $pod = $parser->get_pod_tree;
    is_deeply $pod, [{name => 'NAME', content => "Foo - is foo\n\n"}];
};

subtest 'parses package with heredocs' => sub {
    my $parser = _build_parser()->parse(\<<'EOF');
package Foo;
use base 'ParentClass';
sub new {
    my $foo = <<'FOO';
    hello there from heredoc
FOO
}
EOF

    my $code = $parser->get_code;
    is $code, q{package Foo;
use base 'ParentClass';
sub new {
    my $foo = <<'FOO';
    hello there from heredoc
FOO
}
};
};

subtest 'parses existing pod' => sub {
    my $parser = _build_parser()->parse(\<<'EOF');
package Foo;
sub new {
    my $class = shift;

    return $self;
}

sub foo {}
sub bar {}

1;
__END__
=pod

=head1 NAME

Foo - is foo

=head1 METHODS

=head2 C<foo>

Foo

=head2 C<bar>

Bar

=cut
EOF

    my $pod = $parser->get_pod_tree;
    is_deeply $pod,
      [
        {name => 'NAME',    content => "Foo - is foo\n\n"},
        {name => 'METHODS', content => <<'EOF'}];
=head2 C<foo>

Foo

=head2 C<bar>

Bar

EOF
};

done_testing;

sub _build_parser {
    my (%params) = @_;

    App::Podgrind::PerlParser->new;
}
