use v6;
use Test;
use Test::Redis;
use Redis::Async;

plan 77;

my $port = 16379;

my $redis will leave { .finish } = Test::Redis.new(:$port);
$redis.start;

my $r = Redis::Async.new("localhost:$port");

$r.timeout(0);

start {
    ok my $pub = $r.subscribe('foo'), 'Subscribe to Foo';
    ok $pub.subscribe('bar'), 'Subscribe to Bar';

    for 1..5 {
        is-deeply $pub.message, ('message', 'foo', $_.Str), "Foo $_";
        is-deeply $pub.message, ('message', 'bar', $_.Str), "Bar $_";
    }

    ok $pub.unsubscribe('bar'), 'Unsubscribe Bar';

    for 6..10 {
        is-deeply $pub.message, ('message', 'foo', $_.Str), "Foo $_";
    }

    ok $pub.unsubscribe('foo'), 'Unsubscribe Foo';

    $pub.release;
}

sleep .1;

for 1..5 {
    is $r.publish('foo', $_), 1, "Publish foo $_";
    sleep .05;
    is $r.publish('bar', $_), 1, "Publish bar $_";
    sleep .05;
}

for 6..10 {
    is $r.publish('foo', $_), 1, "Publish foo $_";
    sleep .05;
    is $r.publish('bar', $_), 0, "Publish bar $_";
    sleep .05;
}

start {
    ok my $pub = $r.psubscribe('f*'), 'Psubscribe to f*';
    ok $pub.psubscribe('b*'), 'Psubscribe to b*';

    for 1..5 {
        is-deeply $pub.message, ('pmessage', 'f*', 'foo', $_.Str), "Foo $_";
        is-deeply $pub.message, ('pmessage', 'b*', 'bar', $_.Str), "Bar $_";
    }

    ok $pub.punsubscribe('b*'), 'Unsubscribe Bar';

    for 6..10 {
        is-deeply $pub.message, ('pmessage', 'f*', 'foo', $_.Str), "Foo $_";
    }

    $pub.release;
}

sleep .1;

for 1..5 {
    is $r.publish('foo', $_), 1, "Publish foo $_";
    sleep .05;
    is $r.publish('bar', $_), 1, "Publish bar $_";
    sleep .05;
}

for 6..10 {
    is $r.publish('foo', $_), 1, "Publish foo $_";
    sleep .05;
    is $r.publish('bar', $_), 0, "Publish bar $_";
    sleep .05;
}

done-testing;
