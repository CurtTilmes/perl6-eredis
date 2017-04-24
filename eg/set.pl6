use v6;

use Redis::Async;

my $r = Redis::Async.new("localhost:6379");

$r.set('foo', 'bar');

say $r.get('foo');
