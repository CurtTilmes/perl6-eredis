use v6;
use Test;
use Test::Redis;
use Redis::Async;

plan 6;

my $port = 16379;

my $redis will leave { .finish } = Test::Redis.new(:$port);
$redis.start;

my $r = Redis::Async.new("localhost:$port");

my %hash := $r.hash('myhash');

ok %hash, 'Make a hash';

%hash<a> = 'something';

is %hash<a>, 'something', 'Set';

is $r.hgetall('myhash'), { a => 'something' }, 'Double check';

is %hash<a>:delete, 'something', 'Deleting';

is %hash<a>:exists, False, 'Gone';

is %hash<a>, Nil, 'Still gone';

done-testing;
