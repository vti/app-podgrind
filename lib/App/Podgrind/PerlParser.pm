package App::Podgrind::PerlParser;

use strict;
use warnings;

sub new {
    my $class = shift;

    my $self = {@_};
    bless $self, $class;

    return $self;
}

sub parse {
    my $self = shift;
    my ($input) = @_;

    $self->{document} = PPI::Document->new($input, readonly => 1);

    my $pod = $self->{document}->find(sub { $_[1]->isa('PPI::Token::Pod') });
    if ($pod && @$pod) {
        $self->{pod} = $self->_parse_pod(@$pod);
        $self->{document}->prune('PPI::Token::Pod');
    }

    $self->{document}->prune('PPI::Statement::End');

    return $self;
}

sub get_code {
    my $self = shift;

    return $self->{document} . '';
}

sub get_pod_tree {
    my $self = shift;

    return $self->{pod};
}

sub get_package_name {
    my $self = shift;

    return $self->{document}->find_first('PPI::Statement::Package')
      ->namespace;
}

sub get_end_section {
    my $self = shift;

    my $end =
      $self->{document}->find(sub { $_[1]->isa('PPI::Statement::End') });
    return unless $end && @$end;

    $end = $end->[0];

    $end =~ s{^__END__\n}{};

    return $end;
}

sub get_public_methods {
    my $self = shift;

    my $methods =
      $self->{document}
      ->find(sub { $_[1]->isa('PPI::Statement::Sub') and $_[1]->name });
    return [grep { !m/^_/ } map { $_->name } @$methods];
}

sub _parse_pod {
    my $self = shift;
    my ($pod) = @_;

    my @sections;
    while ($pod =~ m/^=head1 (.*?)$(.*?)(?==head1|=cut)/msgc) {
        push @sections, {
            name => $1,
            content => $2
        }
    }

    return [@sections];
}

1;
