use strict;
use warnings;

use Test::More;
use Test::MonkeyMock;
use Test::Differences;

use App::Podgrind::PODRenderer;

subtest 'fixes year' => sub {
    my $renderer = _build_renderer(
        pod => [
            {
                name    => 'COPYRIGHT AND LICENSE',
                content => 'Copyright (C) 2010, vti'
            }
        ]
    );

    like $renderer->render, qr/2010-2014/;
};

subtest 'fixes year when range' => sub {
    my $renderer = _build_renderer(
        pod => [
            {
                name    => 'COPYRIGHT AND LICENSE',
                content => 'Copyright (C) 2010-2011, vti'
            }
        ]
    );

    like $renderer->render, qr/2010-2014/;
};

subtest 'no year fix the same' => sub {
    my $renderer = _build_renderer(
        pod => [
            {
                name    => 'COPYRIGHT AND LICENSE',
                content => 'Copyright (C) 2014, vti'
            }
        ]
    );

    like $renderer->render, qr/2014/;
};

subtest 'fixes year loosly' => sub {
    my $renderer = _build_renderer(
        pod => [
            {
                name    => 'COPYRIGHT AND LICENSE',
                content => 'Copyright 2010, vti'
            }
        ]
    );

    like $renderer->render, qr/2010-2014/;
};

done_testing;

sub _build_renderer {
    my $renderer = App::Podgrind::PODRenderer->new(
        package => 'Foo',
        config => {author => 'Foo', email => 'foo@bar.com'},
        @_
    );
    $renderer = Test::MonkeyMock->new($renderer);
    $renderer->mock(_current_year => sub { 2014 });
    return $renderer;
}
