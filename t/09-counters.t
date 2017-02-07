use v6;
use Test;
use Test::Redis;
use Redis::Async;

plan 9;

my $port = 16379;

my $redis will leave { .finish } = Test::Redis.new(:$port);
$redis.start;

my $r = Redis::Async.new("localhost:$port");

ok $r.set('counter', 10), 'Set counter';

is $r.get('counter'), 10, 'Correct';

is $r.decr('counter'), 9, 'Decrement';

ok $r.set('toobig', 234293482390480948029348230948), 'Set toobig';

nok try { $r.decr('toobig') }, "Can't decr toobig";

is $r.decrby('counter', 3), 6, 'Decrement by';

is $r.incr('counter'), 7, 'Increment';

is $r.incrby('counter', 4), 11, 'Increment by';

is $r.incrbyfloat('counter', 2.5), 13.5, 'Increment by float';

done-testing;
