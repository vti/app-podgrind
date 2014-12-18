package App::Podgrind;

use strict;
use warnings;

our $VERSION = '0.01';

use File::Copy;
use File::Spec;
use PPI::Document;

use App::Podgrind::PerlParser;
use App::Podgrind::PODRenderer;

sub new {
    my $class = shift;

    my $self = {@_};
    bless $self, $class;

    $self->{config} ||= $self->_read_config_file;

    return $self;
}

sub process {
    my $self = shift;
    my (%params) = @_;

    my $input  = $params{input};
    my $output = $params{output};

    my $stdin;
    if (!$input || $input eq '-') {
        $input = \*STDIN;
        $stdin++;
    }

    if (ref $input eq 'GLOB') {
        local $/;
        my $content = join '', <$input>;
        $input = \$content;
    }

    my $parser = App::Podgrind::PerlParser->new;

    $parser->parse($input);

    my $module = $parser->get_code;

    if (!$self->{prune}) {
        my $renderer = App::Podgrind::PODRenderer->new(
            package           => $parser->get_package_name,
            methods           => $parser->get_public_methods,
            inherited_methods => $parser->get_inherited_methods,
            isa               => $parser->get_isa,
            pod               => $parser->get_pod_tree,
            author            => $self->{config}->{author},
            email             => $self->{config}->{email},
            license           => $self->{config}->{license}
        );
        $module .= "__END__\n" . $renderer->render;
    }

    if ($output) {
        if (ref $output eq 'SCALAR') {
            $$output = $module;
        }
        elsif (ref $output eq 'GLOB') {
            print $output $module;
        }
    }
    elsif ($self->{inplace}) {
        die "you cannot use --inplace with reading from STDIN\n" if $stdin;

        if ($self->{backup}) {
            copy($input, "$input.bak");
        }

        unlink $input;

        open my $fh, '>', $input or die "Can't open file $input: $!";
        print $fh $module;
    }
    else {
        print $module;
    }
}

sub _read_config_file {
    my $self = shift;

    my $file = File::Spec->catfile('.podgrindrc');
    $file = File::Spec->catfile($ENV{HOME}, '.podgrindrc') unless -e $file;

    return {} unless -e $file;

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

        if (my ($heredoc) = $value =~ m/^<<(.*)$/) {
            $value = '';
            while (defined(my $line = <$fh>)) {
                chomp $line;

                if ($line =~ /^$heredoc/) {
                    last;
                }
                else {
                    $value .= $line . "\n";
                }
            }
        }

        $config->{$key} = $value;
    }

    return $config;
}

1;
