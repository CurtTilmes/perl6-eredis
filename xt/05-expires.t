use v6;
use Test;
use Test::Redis;
use Redis::Async;

plan 26;

my $port = 16379;

my $redis will leave { .finish } = Test::Redis.new(:$port);
$redis.start;

my $r = Redis::Async.new("localhost:$port");

ok $r ~~ Redis::Async, 'Created Object';

ok $r.ping, 'Ping';

ok $r.set('expire', 'goes away', 'ex', 1), 'Set expiring key';

is $r.get('expire'), 'goes away', 'Get expiring key';

sleep 2;

is $r.get('expire'), Nil, 'Gone';

ok $r.set('foo', 'bar'), 'Set key';

is $r.expire('foo', 1), 1, 'Expire key';

is $r.get('foo'), 'bar', 'key not expired yet';

sleep 2;

is $r.get('foo'), Nil, 'key expired';

ok $r.set('foo', 'bar'), 'Set key';

is $r.expireat('foo', now+1), 1, 'Expire key with expireat';

is $r.get('foo'), 'bar', 'key not expired yet';

sleep 2;

is $r.get('foo'), Nil, 'key expired';

ok $r.set('foo', 'bar'), 'Set key';

is $r.pexpireat('foo', (now+1).DateTime.posix * 1000),
    1, 'Expire key with pexpireat';

is $r.get('foo'), 'bar', 'key not expired yet';

sleep 2;

is $r.get('foo'), Nil, 'key expired';

ok $r.set('foo', 'bar', 'ex', 10), 'Set key with expire';

ok $r.ttl('foo') > 9, 'TTL ok';

ok $r.pttl('foo') > 9000, 'PTTL ok';

is $r.persist('foo'), 1, 'Persist key';

is $r.persist('notthere'), 0, 'Persist missing key';

is $r.ttl('foo'), -1, 'TTL gone';

is $r.pttl('foo'), -1, 'PTTL gone';

is $r.ttl('notthere'), -2, 'TTL missing';

is $r.pttl('notthere'), -2, 'PTTL missing';

done-testing;
