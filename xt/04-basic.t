use v6;
use Test;
use Test::Redis;
use Redis::Async;

plan 46;

my $port = 16379;

my $redis will leave { .finish } = Test::Redis.new(:$port);
$redis.start;

my $r = Redis::Async.new("localhost:$port");

ok $r ~~ Redis::Async, 'Created Object';

ok $r.ping, 'Ping';

is $r.dbsize, 0, 'DBSIZE empty';

ok $r.bgsave, 'BGSAVE';

ok $r.lastsave, 'LASTSAVE';

is $r.echo('Hello World!'), 'Hello World!', 'Echo message';

is $r.echo('abcdé'), 'abcdé', 'Echo unicode';

ok $r.set('foo', 'this that'), 'Set';

is $r.get('foo'), 'this that', 'Get';

is $r.getrange('foo', 0, 3), 'this', 'Getrange';

is $r.getrange('foo', 5, 8), 'that', 'Getrange';

ok $r.rename('foo', 'foo2'), 'Rename key';

is $r.get('foo2'), 'this that', 'Get new name';

ok $r.renamenx('foo2', 'foo'), 'Rename back';

is $r.getset('foo', 'another'), 'this that', 'GETSET';

ok $r.set('key:😀', '😀'), 'Set unicode';

is $r.get('key:😀'), '😀', 'Get unicode';

nok $r.set('notthere', 'exists', 'XX'), 'Set only if exists';

is $r.get('notthere'), Nil, 'Still not there';

ok $r.set('foo', 'there', 'XX'), 'Set if exists there';

is $r.get('foo'), 'there', 'Get there';

is $r.exists('foo'), 1, 'key exists';

is $r.del('foo'), 1, 'Delete foo';

is $r.get('foo'), Nil, 'foo gone';

is $r.exists('foo'), 0, 'key no longer exists';

is $r.del('notthere'), 0, 'Delete nothing';

is $r.append('foo', 'foo'), 3, 'Append to create a key';

is $r.append('foo', 'bar'), 6, 'Append to value';

is $r.strlen('foo'), 6, 'Value length';

is $r.get('foo'), 'foobar', 'Appended value';

ok $r.move('foo', 1), 'Move key to database 1';

ok $r.select(1), 'Select database 1';

is $r.get('foo'), 'foobar', 'foo in database 1';

is $r.type('foo'), 'string', 'Type of object';

$r.del('foo');

is $r.type('foo'), 'none', 'No Type';

ok $r.select(0), 'Select database 0';

ok $r.mset('k1', 1, 'k2', 2), 'Mset';

ok $r.mset('k3', 3, 'k4', 4), 'Mset';

ok $r.msetnx('k5', 5, 'k6', 6), 'Msetnx';

nok $r.msetnx('k6', 6, 'k7', 7), 'Msetnx already exists';

is $r.dbsize, 7, 'DBSIZE';

ok $r.flushdb, 'FLUSHDB';

is $r.dbsize, 0, 'Database empty';

ok $r.flushall, 'FLUSHALL';

ok $r.time, 'TIME';

ok $r.quit, 'Quit';

done-testing;
