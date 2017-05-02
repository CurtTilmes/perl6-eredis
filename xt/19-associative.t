use v6;
use Test;
use Test::Redis;
use Redis::Async;

plan 6;

my $port = 16379;

my $redis will leave { .finish } = Test::Redis.new(:$port);
$redis.start;

my $r = Redis::Async.new("localhost:$port");

is ($r<a> = 'x'), 'x', 'assign';

is $r<a>, 'x', 'get';

is $r<a>:exists, True, 'exists';

is $r<a>:delete, 'x', 'delete';

is $r<a>:exists, False, 'gone';

is $r<a>, Nil, 'still gone';

done-testing;
