use v6;
use Test;

use Test::Redis;

my $port = 16379;

plan 3;

my $redis = Test::Redis.new(:$port);

ok $redis ~~ Test::Redis, 'Create Test Server';

ok $redis.start, 'Start server';

ok $redis.finish, 'Shutdown server';

done-testing;
