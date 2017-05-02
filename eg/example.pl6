use v6;

use Redis::Async;

my $r = Redis::Async.new("localhost:6379", timeout => 0, max-readers => 50);

$r.set('foo', 'bar');

say $r.get('foo'); # bar

# Can also act like an Associative:

$r<foo> = 'bar';

say $r<foo> if $r<foo>:exists;

$r<foo>:delete;

$r<foo> = 'bar';

say $r.get('foo', :bin);  # Blob:0x<62 61 72>

my $x = $r.dump('foo', :bin);

$r<foo>:delete;

$r.restore('foo', 0, $x);

for ^100 { $r.set("key:$_", $_, :async) }
say "Pending writes: $r.write-pending()";
$r.write-wait;

for ^100 { $r.get("key:$_", :pipeline) }

for ^100 { say $r.value }

my $cursor = $r.scan('key:*');

while $cursor.next -> $x {
    say "$x = $r{$x}";
}

$r.timeout(0);
my $sub = $r.subscribe('foo');

while $sub.message -> @m {
    if @m[0] eq 'message' {
        say "Received message @m[2] on channel @m[1]";
    }
    last if @m[2] eq 'QUIT';
}
