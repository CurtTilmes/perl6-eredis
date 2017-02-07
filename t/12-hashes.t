use v6;
use Test;
use Test::Redis;
use Redis::Async;

plan 16;

my $port = 16379;

my $redis will leave { .finish } = Test::Redis.new(:$port);
$redis.start;

my $r = Redis::Async.new("localhost:$port");

is $r.hset('myhash', 'f1', 1), 1, 'HSET';

is $r.type('myhash'), 'hash', 'Type is hash';

is $r.hget('myhash', 'f1'), 1, 'HGET';

is $r.hsetnx('myhash', 'f1', 2), 0, 'HSETNX already exists';

is $r.hexists('myhash', 'f1'), 1, 'HEXISTS';

ok $r.hmset('myhash', 'f2', 2, 'f3', 3, 'f4', 4), 'HMSET';

is-deeply $r.hgetall('myhash'), { f1 => '1', f2 => '2', f3 => '3', f4 => '4' },
    'HGETALL';

is $r.hincrby('myhash', 'f1', 5), 6, 'HINCRBY';

is $r.hincrbyfloat('myhash', 'f2', 4.5), 6.5, 'HINCRBYFLOAT';

is-deeply $r.hkeys('myhash'), <f1 f2 f3 f4>, 'HKEYS';

is $r.hlen('myhash'), 4, 'HLEN';

is-deeply $r.hmget('myhash', 'f3', 'f1', 'f4'), ('3', '6', '4'), 'HMGET';

is-deeply $r.hvals('myhash'), ('6', '6.5', '3', '4'), 'HVALS';

is $r.hdel('myhash', 'f1'), 1, 'HDEL';

nok $r.hget('myhash', 'f1'), 'Deleted field';

ok $r.del('myhash'), 'Delete hash';

done-testing;
