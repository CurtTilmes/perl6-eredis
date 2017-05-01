use v6;
use Test;
use Test::Redis;
use Redis::Async;

plan 20;

my $port = 16379;

my $redis will leave { .finish } = Test::Redis.new(:$port);
$redis.start;

my $r = Redis::Async.new("localhost:$port");

is $r.lpush('mylist', 1, 2, 3), 3, 'LPUSH';

is $r.lpushx('nolist', 1), 0, 'LPUSHX';

is $r.type('mylist'), 'list', 'Type of list';

is-deeply $r.lrange('mylist', 0, -1), ("3", "2", "1"), 'LRange list';

is $r.lindex('mylist', 1), 2, 'LINDEX';

ok $r.linsert('mylist', 'BEFORE', 2, 2.5), 'LINSERT';

is $r.lindex('mylist', 1), 2.5, 'LINDEX';

is $r.llen('mylist'), 4, 'LLEN';

is $r.lpop('mylist'), 3, 'LPOP';

is $r.lrem('mylist', 0, 2.5), 1, 'LREM';

nok try { $r.lset('mylist', 5, 'something') }, 'LSET out of range';

ok $r.lset('mylist', 0, 5), 'LSET first element to 5';

is $r.lindex('mylist', 0), 5, 'Worked';

is $r.rpush('mylist', 6, 7, 8, 9, 10), 7, 'RPUSH';

ok $r.ltrim('mylist', 0, 4), 'LTRIM';

is $r.llen('mylist'), 5, 'LLEN';

is $r.rpushx('nolist', 1), 0, 'RPUSHX missing key';

is $r.rpop('mylist'), 8, 'RPOP';

is $r.rpoplpush('mylist', 'mylist'), 7, 'RPOPLPUSH';

ok $r.del('mylist'), 'Remove mylist';

done-testing;
