use v6;
use Test;
use Test::Redis;
use Redis::Async;

plan 8;

my $port = 16379;

my $redis will leave { .finish } = Test::Redis.new(:$port);
$redis.start;

my $r = Redis::Async.new("localhost:$port");

for 1..100 {
    $r.set("key:$_", $_, :async);
    $r.sadd('myset', $_, :async);
    $r.hset('myhash', "field:$_", $_, :async);
    $r.zadd('myzset', $_, "member:$_", :async);
}

$r.write-wait;

ok my $scan-cursor = $r.scan('key:*'), 'Create SCAN Cursor';

ok my $sscan-cursor = $r.sscan('myset'), 'Create SSCAN Cursor';

ok my $hscan-cursor = $r.hscan('myhash'), 'Create HSCAN Cursor';

ok my $zscan-cursor = $r.zscan('myzset'), 'Create ZSCAN Cursor';

my $i = 0;

$i++ while $scan-cursor.next;

is $i, 100, 'SCANed all keys';

$i = 0;

$i++ while $sscan-cursor.next;

is $i, 100, 'SSCANed all values';

$i = 0;

$i++ while $hscan-cursor.next;

is $i, 100, 'HSCANed all fields';

$i = 0;

$i++ while $zscan-cursor.next;

is $i, 100, 'ZSCANed all members';

done-testing;
