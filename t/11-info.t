use v6;
use Test;
use Test::Redis;
use Redis::Async;

plan 3;

my $port = 16379;

my $redis will leave { .finish } = Test::Redis.new(:$port);

ok $redis.start, 'Start test server';

my $r = Redis::Async.new("localhost:$port");

ok my $info = $r.info('all'), 'INFO';

ok $info ~~ Hash, 'INFO hash';

done-testing;
