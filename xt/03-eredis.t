use v6;
use Test;
use Test::Redis;
use Eredis;

my $port = 16379;

plan 9;

my $redis = Test::Redis.new(:$port);
$redis.start;

my $e = try Eredis.new;

if $!
{
    skip-rest 'Skipping tests, no eredis library.';
    done-testing;
    exit 0;
}

ok $e, 'Created Eredis object';

ok $e.host-add('localhost', $port), 'host_add';

ok my $r = $e.reader, 'Create Reader Object';

ok my $reply = $r.cmd('set foo bar'), 'Set';

ok $reply.value, 'Check Set succeed';

ok $reply = $r.cmd('get foo'), 'Get';

is $reply.value, 'bar', 'Check value';

ok $reply = $r.cmd('get'.encode, 'foo'.encode), 'Get argv';

is $reply.value, 'bar', 'Check value';

$r.release;

$e.shutdown;

$e.free;

$redis.finish;

done-testing;
