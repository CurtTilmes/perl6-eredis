use v6;
use Test;
use Test::Redis;
use Redis::Async;

plan 21;

my $port = 16379;

my $redis will leave { .finish } = Test::Redis.new(:$port);
$redis.start;

my $r = Redis::Async.new("localhost:$port");

is $r.sadd('set-a', 'a', 'b', 'c'), 3, 'SADD';

is $r.scard('set-a'), 3, 'SCARD';

is $r.sismember('set-a', 'b'), 1, 'SISMEMBER present';

is $r.sismember('set-a', 'd'), 0, 'SISMEMBER not present';

is-deeply $r.smembers('set-a').sort, ('a', 'b', 'c'), 'SMEMBERS';

ok $r.srandmember('set-a') ~~ 'a'|'b'|'c', 'SRANDMEMBER';

ok $r.spop('set-a') ~~ 'a'|'b'|'c', 'SPOP';

is $r.scard('set-a'), 2, 'Removed';

is $r.srem('set-a', 'a', 'b', 'c'), 2, 'SREM 2';

$r.sadd('set-a', 'a', 'b', 'c', 'd');
$r.sadd('set-b', 'c', 'd', 'e', 'f');

is-deeply $r.sinter('set-a', 'set-b').sort, ('c', 'd'), 'SINTER';

ok $r.sinterstore('set-inter', 'set-a', 'set-b'), 'SINTERSTORE';

is-deeply $r.smembers('set-inter').sort, ('c', 'd'), 'Check';

is-deeply $r.sdiff('set-a', 'set-b').sort, ('a', 'b'), 'SDIFF';

ok $r.sdiffstore('set-diff', 'set-a', 'set-b'), 'SDIFFSTORE';

is-deeply $r.smembers('set-diff').sort, ('a', 'b').sort, 'Check';

is-deeply $r.sunion('set-a', 'set-b').sort, <a b c d e f>, 'SUNION';

ok $r.sunionstore('set-union', 'set-a', 'set-b'), 'SUNIONSTORE';

is-deeply $r.smembers('set-union').sort, <a b c d e f>, 'Check';

ok $r.smove('set-a', 'set-b', 'a'), 'SMOVE';

is-deeply $r.smembers('set-a').sort, <b c d>, 'A is right';

is-deeply $r.smembers('set-b').sort, <a c d e f>, 'B is right';

done-testing;


