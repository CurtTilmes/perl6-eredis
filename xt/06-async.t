use v6;
use Test;
use Test::Redis;
use Redis::Async;

plan 6;

my $port = 16379;

my $redis will leave { .finish } = Test::Redis.new(:$port);
$redis.start;

my $r = Redis::Async.new("localhost:$port");

ok $r.set('my key', 'something foo', :async), 'Set async';

$r.write-wait;

is $r.get('my key'), 'something foo', 'Got async reply';

for 1..100 {
    $r.set("key:$_", $_, :async);
}

$r.write-wait;

for 1..100 {
    $r.get("key:$_", :pipeline);
}

my $correct = 0;
for 1..100 {
    $correct++ if $r.value eq $_;
}

is $correct, 100, "100 pipelined replies";

is $r.get('my key'), 'something foo', 'pipeline clear';

ok $r.del('my key'), 'Delete my key';

is $r.del((1..100).map({"key:$_"})), 100, 'Delete 100 keys';

done-testing;
