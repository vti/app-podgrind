package App::Podgrind::PerlParser;

use strict;
use warnings;

use PPI::Document;

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

    my $package = $self->{document}->find_first('PPI::Statement::Package');
    return $package ? $package->namespace : undef;
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
    my ($document) = @_;

    $document ||= $self->{document};

    my $methods =
      $document->find(sub { $_[1]->isa('PPI::Statement::Sub') and $_[1]->name }
      );
    return [] unless $methods && @$methods;

    my @public =
      grep { $_->name ne 'DESTROY' && $_->name ne 'AUTOLOAD' }
      grep { $_->name !~ m/^_/ } @$methods;

    my $result = [];
    foreach my $public (@public) {
        my $stmt =
          $public->find(sub { $_[1]->isa('PPI::Statement::Variable') }) || [];

        my ($unpack) = grep {
            $_->find(
                sub {
                    $_[1]->isa('PPI::Token::Magic')
                      and $_[1]->content eq '@_';
                }
              )
        } @$stmt;

        my @argv;
        if ($unpack) {
            my $list =
              $unpack->find(sub { $_[1]->isa('PPI::Structure::List') });
              if ($list) {
                my $symbols =
                  $list->[0]->find(sub { $_[1]->isa('PPI::Token::Symbol') });
                @argv = grep { $_ ne '$self' } map { $_->content } @$symbols if $symbols;
            }
        }

        push @$result,
          {
            name => $public->name,
            argv => \@argv
          };
    }

    return $result;
}

sub get_isa {
    my $self = shift;

    my @isa;
    my $includes = $self->{document}->find('Statement::Include') || [];
    for my $node (@$includes) {
        next if grep { $_ eq $node->module } qw{ lib };

        if (grep { $_ eq $node->module } qw{ base parent }) {

            my @meat = grep {
                     $_->isa('PPI::Token::QuoteLike::Words')
                  || $_->isa('PPI::Token::Quote')
            } $node->arguments;

            foreach my $token (@meat) {
                if (   $token->isa('PPI::Token::QuoteLike::Words')
                    || $token->isa('PPI::Token::Number'))
                {
                    push @isa, $token->literal;
                }
                else {
                    next if $token->content =~ m/^base|parent$/;
                    push @isa, $token->string;
                }
            }
            next;
        }
    }

    return \@isa;
}

sub get_inherited_methods {
    my $self = shift;

    my $isa = $self->get_isa;
    return [] unless $isa && @$isa;

    my @isa_methods;
    foreach my $isa_class (@$isa) {
        eval "require $isa_class" or die $@;

        $isa_class =~ s{::}{/}g;
        my $path = $INC{$isa_class . '.pm'};

        my $doc = PPI::Document->new($path, readonly => 1);

        my $public_methods = $self->get_public_methods($doc);

        foreach my $public_method (@$public_methods) {
            push @isa_methods, $public_method
              unless grep { $public_method->{name} eq $_->{name} } @isa_methods;
        }
    }

    my @methods;

    my $public_methods = $self->get_public_methods;
    foreach my $isa_method (@isa_methods) {
        push @methods, $isa_method
          unless grep { $isa_method->{name} eq $_->{name} } @$public_methods;
    }

    return \@methods;
}

sub _parse_pod {
    my $self = shift;
    my ($pod) = @_;

    my @sections;
    while ($pod =~ m/^=head1 (.*?)$(.*?)(?==head1|=cut)/msgc) {
        my ($name, $content) = ($1, $2);

        $content =~ s{^\r?\n*}{};
        $content =~ s{\r?\n*$}{};

        push @sections,
          {
            name    => $name,
            content => "$content\n\n"
          };
    }

    return [@sections];
}

1;
