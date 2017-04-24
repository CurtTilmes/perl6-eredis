use v6;
use Test;
use Test::Redis;
use Redis::Async;

plan 7;

my $port = 16379;

my $redis will leave { .finish } = Test::Redis.new(:$port);
$redis.start;

my $r = Redis::Async.new("localhost:$port");
 
$r.set('mykey', 'foobar');

is $r.bitcount('mykey'), 26, 'BITCOUNT';

is $r.bitcount('mykey', 0, 0), 4, 'Count 0';

is $r.bitcount('mykey', 1, 1), 6, 'Count 1';

$r.set('key1', 'foobar');
$r.set('key2', 'abcdef');

is $r.bitop('AND', 'dest', 'key1', 'key2'), 6, 'BITOP';

is $r.get('dest'), '`bc`ab', 'Check AND result';

is $r.setbit('mykey', 7, 1), 0, 'SETBIT';

is $r.getbit('mykey', 7), 1, 'GETBIT';

done-testing;
