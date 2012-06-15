package App::Podmaker;

use strict;
use warnings;

use File::Spec;
use Pod::Parser;
use PPI::Document;

sub new {
    my $class = shift;

    my $self = {@_};
    bless $self, $class;

    $self->{config} ||= $self->read_config_file;

    return $self;
}

sub process {
    my $self = shift;
    my (%params) = @_;

    my $input  = $params{input};
    my $output = $params{output};

    if (ref $input eq 'GLOB') {
        local $/;
        my $content = join '', <$input>;
        $input = \$content;
    }

    $self->{document} = PPI::Document->new($input, readonly => 1);

    my $pod =
      $self->{document}->find(sub { $_[1]->isa('PPI::Token::Pod') });
    if ($pod && @$pod) {
        $self->{pod} = $self->_parse_pod(@$pod);
        $self->{document}->prune('PPI::Token::Pod');
    }

    $self->{document}->prune('PPI::Statement::End');

    my $module = $self->{document} . "__END__\n" . $self->render_pod;

    if ($output) {
        if (ref $output eq 'SCALAR') {
            $$output = $module;
        }
        elsif (ref $output eq 'GLOB') {
            print $output $module;
        }
    }
    else {
        return $module;
    }
}

sub render_pod {
    my $self = shift;

    my @sections =
      $self->{pod}
      ? map { $_->{name} } @{$self->{pod}}
      : (qw/NAME METHODS AUTHOR/, 'COPYRIGHT AND LICENSE');

    my $pod = "=pod\n\n";

    foreach my $section (@sections) {
        if ($section eq 'NAME') {
            $pod .= $self->render_package_name;
        }
        elsif ($section eq 'METHODS') {
            $pod .= $self->render_methods;
        }
        elsif ($section eq 'AUTHOR') {
            $pod .= $self->render_author;
        }
        elsif ($section eq 'COPYRIGHT AND LICENSE') {
            $pod .= $self->render_license;
        }
        else {
            $pod .= '=head1 ' . $section->{name};
            $pod .= $section->{content};
        }
    }

    if (!grep { $_ eq 'METHODS' } @sections) {
        $pod .= $self->render_methods;
    }

    if (!grep { $_ eq 'AUTHOR' } @sections) {
        $pod .= $self->render_author;
    }

    if (!grep { $_ eq 'COPYRIGHT AND LICENSE' } @sections) {
        $pod .= $self->render_license;
    }

    $pod  .= "=cut\n";

    return $pod;
}

sub read_config_file {
    my $self = shift;

    my $file = File::Spec->catfile($ENV{HOME}, '.podmaker');
    return {} unless -f $file;

    my $config = {};

    open my $fh, '<', $file or die "Can't open file '$file': $!";
    while (defined(my $line = <$fh>)) {
        chomp $line;

        next if $line eq '';

        my ($key, $value) = split /=/, $line;
        next unless defined $key && defined $value;

        for ($key, $value) {
            s{^\s*}{};
            s{\s*$}{};
        }

        $config->{$key} = $value;
    }

    return $config;
}

sub render_package_name {
    my $self = shift;

    my $module = $self->get_package_name;

return <<"EOF";
=head1 NAME

$module - Module

EOF
}

sub render_methods {
    my $self = shift;

    my @methods = $self->get_public_methods;

    my $pod = '';
    $pod .= <<'EOF';
=head1 METHODS

EOF

    if (grep { $_ eq 'new' } @methods) {
        @methods = ('new', grep { $_ ne 'new' } @methods);
    }

    my @old_methods;
    if ($self->{pod}) {
        if (my ($methods) = grep { $_->{name} eq 'METHODS' } @{$self->{pod}})
        {
            while ($methods->{content} =~ m/^=head2 C<(.*?)>(.*?)(?==head2|\z)/msgc) {
                push @old_methods,
                  { method  => $1,
                    content => $2
                  };
            }
        }
    }

    foreach my $method (@methods) {
        $pod .= <<"EOF";
=head2 C<$method>

EOF
        my ($old_method) = grep {$_->{method} eq $method} @old_methods;
        if ($old_method) {
            $old_method->{content} =~ s{^\s*}{};
            $pod .=  $old_method->{content};
        }
    }

    return $pod;
}

sub render_author {
    my $self = shift;

    my $author = $self->{config}->{author} || 'Author';
    my $email = $self->{config}->{email} || 'Email';

    my $pod = '';

    $pod .= <<"EOF";
=head1 AUTHOR

$author, C<$email>

EOF

    return $pod;
}

sub render_license {
    my $self = shift;

    my $author = $self->{config}->{author} || 'Author';
    my $license = $self->{config}->{license} || 'artistic2';

    my $current_year = (localtime)[5] + 1900;
    my $years = $current_year;

    my $pod = '';

    $pod .= <<"EOF";
=head1 COPYRIGHT AND LICENSE

Copyright (C) $years, $author.

This module is free software; you can redistribute it and/or modify it under the
same terms as Perl 5.10.0. For more details, see the full text of the licenses
in the directory LICENSES.

This program is distributed in the hope that it will be useful, but without any
warranty; without even the implied warranty of merchantability or fitness for
a particular purpose.

EOF

    return $pod;
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
    return grep { !m/^_/ } map { $_->name } @$methods;
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
