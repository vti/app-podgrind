package App::Podgrind::PODRenderer;

use strict;
use warnings;

sub new {
    my $class = shift;
    my (%params) = @_;

    my $self = {};
    bless $self, $class;

    $self->{package}           = $params{package};
    $self->{methods}           = $params{methods};
    $self->{inherited_methods} = $params{inherited_methods};
    $self->{isa}               = $params{isa};
    $self->{pod}               = $params{pod};
    $self->{author}            = $params{author};
    $self->{email}             = $params{email};
    $self->{license}           = $params{license};

    return $self;
}

sub render {
    my $self = shift;

    $self->{pod} ||= [];
    my $sections = $self->{pod};

    if (!grep { $_->{name} eq 'NAME' } @$sections) {
        unshift @$sections,
          {name => 'NAME', content => $self->_render_package_name};
    }

    if (!grep { $_->{name} eq 'SYNOPSIS' } @$sections) {
        $self->_insert_section_after('NAME',
            {name => 'SYNOPSIS', content => ''});
    }

    if (!grep { $_->{name} eq 'DESCRIPTION' } @$sections) {
        $self->_insert_section_after('SYNOPSIS',
            {name => 'DESCRIPTION', content => ''});
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

    if (@{$self->{isa} || []} && !grep { $_->{name} eq 'ISA' } @$sections) {
        $self->_insert_section_before('METHODS',
            {name => 'ISA', content => ''});

        if (!grep { $_->{name} eq 'INHERITED METHODS' } @$sections) {
            $self->_insert_section_after('METHODS',
                {name => 'INHERITED METHODS'});
        }
    }

    my $pod = "=pod\n\n";

    foreach my $section (@$sections) {
        $pod .= '=head1 ' . $section->{name} . "\n\n";

        if ($section->{name} eq 'NAME') {
            $pod .= $section->{content};
        }
        elsif ($section->{name} eq 'ISA') {
            $pod .= $self->_render_isa;
        }
        elsif ($section->{name} eq 'METHODS') {
            $pod .= $self->_render_methods;
        }
        elsif ($section->{name} eq 'INHERITED METHODS') {
            $pod .= $self->_render_inherited_methods;
        }
        elsif ($section->{name} eq 'AUTHOR') {
            $pod .= $self->_render_author;
        }
        elsif ($section->{name} eq 'COPYRIGHT AND LICENSE') {
            $pod .= $self->_render_license;
        }
        else {
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
$module - Module

EOF
}

sub _render_isa {
    my $self = shift;

    my @isa = @{$self->{isa} || []};
    return '' unless @isa;

    my $pod = '';

    $pod .= join ', ', map { "L<$_>" } @isa;

    $pod .= "\n\n";

    return $pod;
}

sub _render_methods {
    my $self = shift;

    my @methods = @{$self->{methods} || []};

    my $pod = '';

    if (grep { $_->{name} eq 'new' } @methods) {
        @methods = (
            {name => 'new'},
            sort   { $a->{name} cmp $b->{name} }
              grep { $_->{name} ne 'new' } @methods
        );
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
        my $argv = '';
        if ($method->{argv} && @{$method->{argv}}) {
            $argv = '(' . join(', ', @{$method->{argv}}) . ')';
        }

        $pod .= <<"EOF";
=head2 C<$method->{name}$argv>

EOF
        $pod .= $method->{comment} . "\n\n" if $method->{comment};

        my ($old_method) =
          grep { $_->{method} eq $method->{name} } @old_methods;
        if ($old_method) {
            $old_method->{content} =~ s{^\r?\n*}{};
            $pod .= $old_method->{content};
        }
    }

    return $pod;
}

sub _render_inherited_methods {
    my $self = shift;

    my @methods = @{$self->{inherited_methods} || []};

    my $pod = '';

    if (grep { $_->{name} eq 'new' } @methods) {
        @methods = (
            {name => 'new'},
            sort   { $a->{name} cmp $b->{name} }
              grep { $_->{name} ne 'new' } @methods
        );
    }

    foreach my $method (@methods) {
        my $argv = '';
        if ($method->{argv} && @{$method->{argv}}) {
            $argv = '(' . join(', ', @{$method->{argv}}) . ')';
        }

        $pod .= <<"EOF";
=head2 C<$method->{name}$argv>

EOF
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

    my $current_year = $self->_current_year;
    my $years = $self->{years} || $current_year;

    if (
        my ($section) =
        grep { $_->{name} eq 'COPYRIGHT AND LICENSE' } @{$self->{pod}}
      )
    {
        if (
            $section->{content}
            && (my ($year) =
                $section->{content} =~ m/Copyright.*?(\d\d\d\d)(?:-\d\d\d\d)?,/)
          )
        {
            if ($year ne $current_year) {
                $years = "$year-$current_year";
            }
        }
    }

    my $pod = '';

    $pod .= <<"EOF";
Copyright (C) $years, $author.

$license
EOF

    return $pod;
}

sub _current_year {
    my $self = shift;

    return (localtime)[5] + 1900;
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
