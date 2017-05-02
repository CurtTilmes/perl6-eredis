use v6;
use Test;
use Test::Redis;
use Redis::Async;

plan 5;

my $port = 16379;

my $redis will leave { .finish } = Test::Redis.new(:$port);
$redis.start;

my $r = Redis::Async.new("localhost:$port");

ok $r.set('mykey', 10), 'Set value';

my $val = Blob.new(0,192,10,6,0,248,114,63,197,251,251,95,40);

is $r.dump('mykey', :bin), $val, 'Dumped key';

$r.del('mykey');

is $r.restore('mykey', 0, $val), 'OK', 'Restored ok';

is $r.get('mykey'), 10, 'Restored value';

throws-like { $r.restore('mykey', 0, $val) }, X::Eredis,
    message => 'ERR Target key name is busy.';

done-testing;
