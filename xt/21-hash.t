use v6;
use Test;
use Test::Redis;
use Redis::Async;
use Redis::Objects;

plan 6;

my $port = 16379;

my $redis-server will leave { .finish } = Test::Redis.new(:$port);
$redis-server.start;

my $redis = Redis::Async.new("localhost:$port");

my %hash := Redis::Hash.new(:$redis, key => 'myhash');

ok %hash, 'Make a hash';

%hash<a> = 'something';

is %hash<a>, 'something', 'Set';

is $redis.hgetall('myhash'), { a => 'something' }, 'Double check';

is %hash<a>:delete, 'something', 'Deleting';

is %hash<a>:exists, False, 'Gone';

is %hash<a>, Nil, 'Still gone';

done-testing;
