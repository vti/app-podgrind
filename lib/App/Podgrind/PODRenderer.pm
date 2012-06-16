package App::Podgrind::PODRenderer;

use strict;
use warnings;

sub new {
    my $class = shift;

    my $self = {@_};
    bless $self, $class;

    return $self;
}

sub render {
    my $self = shift;

    my @sections =
      $self->{pod}
      ? map { $_->{name} } @{$self->{pod}}
      : (qw/NAME METHODS AUTHOR/, 'COPYRIGHT AND LICENSE');

    my $pod = "=pod\n\n";

    foreach my $section (@sections) {
        if ($section eq 'NAME') {
            $pod .= $self->_render_package_name;
        }
        elsif ($section eq 'METHODS') {
            $pod .= $self->_render_methods;
        }
        elsif ($section eq 'AUTHOR') {
            $pod .= $self->_render_author;
        }
        elsif ($section eq 'COPYRIGHT AND LICENSE') {
            $pod .= $self->_render_license;
        }
        else {
            $pod .= '=head1 ' . $section->{name};
            $pod .= $section->{content};
        }
    }

    if (!grep { $_ eq 'METHODS' } @sections) {
        $pod .= $self->_render_methods;
    }

    if (!grep { $_ eq 'AUTHOR' } @sections) {
        $pod .= $self->_render_author;
    }

    if (!grep { $_ eq 'COPYRIGHT AND LICENSE' } @sections) {
        $pod .= $self->_render_license;
    }

    $pod  .= "=cut\n";

    return $pod;
}

sub _render_package_name {
    my $self = shift;

    my $module = $self->{package};

return <<"EOF";
=head1 NAME

$module - Module

EOF
}

sub _render_methods {
    my $self = shift;

    my @methods = @{$self->{methods} || []};

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

sub _render_author {
    my $self = shift;

    my $author = $self->{author} || 'Author';
    my $email = $self->{email} || 'Email';

    my $pod = '';

    $pod .= <<"EOF";
=head1 AUTHOR

$author, C<$email>

EOF

    return $pod;
}

sub _render_license {
    my $self = shift;

    my $author = $self->{author} || 'Author';
    my $license = $self->{license} || 'artistic2';

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

1;
