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

    $self->{pod} ||= [];
    my $sections = $self->{pod};

    if (!grep { $_->{name} eq 'NAME' } @$sections) {
        unshift @$sections, {name => 'NAME'};
    }

    if (!grep { $_->{name} eq 'COPYRIGHT AND LICENSE' } @$sections) {
        push @$sections, {name => 'COPYRIGHT AND LICENSE'};
    }

    if (!grep { $_->{name} eq 'AUTHOR' } @$sections) {
        $self->_insert_section_before('COPYRIGHT AND LICENSE',
            {name => 'AUTHOR'});
    }

    if (!grep { $_->{name} eq 'METHODS' } @$sections) {
        if (grep { $_->{name} eq 'DESCRIPTION' } @$sections) {
            $self->_insert_section_after('DESCRIPTION',
                {name => 'METHODS', content => ''});
        }
        else {
            $self->_insert_section_before('AUTHOR',
                {name => 'METHODS', content => ''});
        }
    }

    if (!grep { $_->{name} eq 'ISA' } @$sections) {
            $self->_insert_section_before('METHODS',
                {name => 'ISA', content => ''});
    }

    my $pod = "=pod\n\n";

    foreach my $section (@$sections) {
        if ($section->{name} eq 'NAME') {
            $pod .= $self->_render_package_name;
        }
        elsif ($section->{name} eq 'ISA') {
            $pod .= $self->_render_isa;
        }
        elsif ($section->{name} eq 'METHODS') {
            $pod .= $self->_render_methods;
        }
        elsif ($section->{name} eq 'AUTHOR') {
            $pod .= '=head1 ' . $section->{name} . "\n";
            $pod .= $self->_render_author;
        }
        elsif ($section->{name} eq 'COPYRIGHT AND LICENSE') {
            $pod .= '=head1 ' . $section->{name} . "\n";
            $pod .= $self->_render_license;
        }
        else {
            $pod .= '=head1 ' . $section->{name};
            $pod .= $section->{content};
        }
    }

    $pod .= "=cut\n";

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

sub _render_isa {
    my $self = shift;

    my @isa = @{$self->{isa} || []};
    return '' unless @isa;

    my $pod = '';
    $pod .= <<'EOF';
=head1 ISA

EOF

    $pod .= join ', ', map { "L<$_>" } @isa;

    $pod .= "\n\n";

    return $pod;
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
        if (my ($methods) = grep { $_->{name} eq 'METHODS' } @{$self->{pod}}) {
            while ($methods->{content} =~
                m/^=head2 C<(.*?)>(.*?)(?==head2|\z)/msgc)
            {
                push @old_methods,
                  {
                    method  => $1,
                    content => $2
                  };
            }
        }
    }

    foreach my $method (@methods) {
        $pod .= <<"EOF";
=head2 C<$method>

EOF
        my ($old_method) = grep { $_->{method} eq $method } @old_methods;
        if ($old_method) {
            $old_method->{content} =~ s{^\r?\n*}{};
            $pod .= $old_method->{content};
        }
    }

    return $pod;
}

sub _render_author {
    my $self = shift;

    my $author = $self->{author} || 'Author';
    my $email  = $self->{email}  || 'Email';

    my $pod = '';

    $pod .= <<"EOF";

$author, C<$email>

EOF

    return $pod;
}

sub _render_license {
    my $self = shift;

    my $author  = $self->{author}  || 'Author';
    my $license = $self->{license} || <<'LICENSE';
This program is free software, you can redistribute it and/or modify it under
the terms of the Artistic License version 2.0.

This program is distributed in the hope that it will be useful, but without any
warranty; without even the implied warranty of merchantability or fitness for
a particular purpose.
LICENSE

    my $current_year = (localtime)[5] + 1900;
    my $years = $self->{years} || $current_year;

    my $pod = '';

    $pod .= <<"EOF";

Copyright (C) $years, $author.

$license
EOF

    return $pod;
}

sub _insert_section_before {
    my $self = shift;
    my ($before, $section) = @_;

    my $sections = $self->{pod};

    for (my $i = 0; $i < @$sections; $i++) {
        if ($before eq $self->{pod}->[$i]->{name}) {
            splice @$sections, $i, 0, $section;

            return;
        }
    }

    die "section '$before' not found";
}

sub _insert_section_after {
    my $self = shift;
    my ($after, $section) = @_;

    my $sections = $self->{pod};

    for (my $i = 0; $i < @$sections; $i++) {
        if ($after eq $self->{pod}->[$i]->{name}) {
            splice @$sections, $i + 1, 0, $section;

            return;
        }
    }

    die "section '$after' not found";
}

1;
