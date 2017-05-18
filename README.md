# Redis::Async - A high-performance client for Redis

This module includes bindings for the
[Eredis](https://github.com/EulerianTechnologies/eredis) client
library for [Redis](https://redis.io).

Eredis is a C client library built over Hiredis. It is lightweight,
high performance, reentrant and thread-safe.

## INSTALLATION

This module depends on the
[Eredis](https://github.com/EulerianTechnologies/eredis) library, so
it must be installed first.  Then just use `zef` to install this
package from the Perl 6 ecosystem:

    zef install Redis::Async

## Basic Usage

    use Redis::Async;

    my $r = Redis::Async.new("localhost:6379");

    $r.set('foo', 'bar');

    say $r.get('foo'); # bar

## Notes

Case doesn't matter for commands `$r.GET` and `$r.get` are the same
thing with a few exceptions:

* `hgetall` returns a `Hash`

* `info` returns a `Hash`

* `keys` defaults to pattern '*' -- Caution, this can take a very long
  time if you have a lot of keys!  For production, `scan` may be a
  better option.

* `subscribe` and `psubscribe` should be lower case.

* `scan`, `sscan`, `hscan`, and `zscan` should be lower case.

An `Instant` will be converted into epoch seconds.

    $r.expireat('foo', now+5);  # same as $r.expire('foo', 5)

See [redis.io](https://redis.io/commands) for the complete list of
commands.  Note carefully the version of your Redis server and if you
are using an older version, which commands are valid.

## Timeouts

You can set the Redis timeout with `$r.timeout($seconds)`.  You can
disable timeouts entirely with `$r.timeout(0)`. This is highly
recommended if you use blocking read requests -- instead specify a
timeout with the command.  Timeouts should probably also be disabled
for publish/subscribe.  You can also set timeout on creation:

    my $r = Redis::Async.new('localhost:6379', timeout => 0);

## Multiple Redis servers

You can configure multiple redundant (NOT clustered) Redis servers in
several ways.

List multiple servers on creation:

    my $r = Redis::Async.new('server1:6379', 'server2:6379');

Add additional servers:

    $r.host-add('server3:6379');

Or list servers in a configuration file, one line per host:port and
add the file, alone, or as an option to `.new(host-file => 'my-hosts.conf')`

    $r.host-file('my-hosts.conf');

The first host provided becomes the "preferred" one.  It will always
reconnect to that one in case of a down/up event.

You can set the number of retries on failure with `$r.retry($retries)`
(defaults to 1) after which the client will fall back to the next
server.  You can also set retries with an option to new:

    my $r = Redis::Async.new('localhost:6379', retries => 2);

## Associative usage

`Redis::Async` also does the `Associative` role:

    $r<foo> = 'bar';

    say $r<foo> if $r<foo>:exists;

    $r<foo>:delete;

## Binary data

Strings are encoded as utf8 by default, but you can also pass in Blobs
of binary data.  Some commands like `RESTORE` require this.

Strings are also decoded as utf8 by default, you can request binary
values with the `:bin` flag.  It is highly recommended for `dump`.

    say $r.get('foo', :bin);  # Blob:0x<62 61 72>

    my $x = $r.dump('foo', :bin);

    $r<foo>:delete;

    $r.restore('foo', 0, $x);

## Async writing

If you use the :async option, the write calls will be queued and sent
to the Redis server in the background and the call will return
immediately.  This can dramatically speed up multiple writes.  You can
wait for pending writes to complete with $r.write-wait.

    for ^100 { $r.set("key:$_", $_, :async) }
    say "Pending writes: $r.write-pending()";
    $r.write-wait;

## Pipeline reads

You can also issue multiple reads without waiting for the replies,
then later read the replies.  This will pipeline the requests more
efficiently and speed up performance.

    for ^100 { $r.get("key:$_", :pipeline) }

    for ^100 { say $r.value }

## SCANing

The SCAN commands have special lower case functions that return a
`Redis::Cursor` object that has a `.next` method to get the next
element.

    my $cursor = $r.scan('key:*');

    while $cursor.next -> $x {
        say "$x = $r{$x}";
    }

The scan commands also just take the parameters themselves, not the
'MATCH' and 'COUNT' strings.

## Publish/Subscribe

The `subscribe` and `psubscribe` commands return a `Redis::PubSub`
object that can read messages with .message:

    $r.timeout(0);
    my $sub = $r.subscribe('foo');

    while $sub.message -> @m {
        if @m[0] eq 'message' {
            say "Received message @m[2] on channel @m[1]";
        }
        last if @m[2] eq 'QUIT';
    }

## Multiple threads

You can use a single `Redis::Async` object to issue requests from
multiple threads simultaneously.  Internally each thread will get its
own communication channel so the requests won't get mixed up. You
can't, therefore issue a pipelined read request in one thread and the
corresponding `reply` request in a different thread.  You can set the
maximum number of readers with max-readers:

    $r.max-readers(50);

Max readers will default to 16, so if you want to access Redis from
more threads than that, increase it.  As a convenience for Rakudo
users, if you set the RAKUDO_MAX_THREADS environment variable,
max-readers will be set to that number.  You can also specify the
max-readers option to new():

    $r = Redis::Async.new('localhost:6379', max-readers => 50);

## Perlish objects

EXPERIMENTAL, not everything works yet

You can bind an array to a Redis List like this:

    my @list := $r.list('some-list-key');
    @list.push(1,2,3);
    say @list[1]; # 2

or a Redis Hash like this:

    my %hash := $r.hash('some-hash-key');
    %hash<a> = 'something';
    say %hash<a>; # something

## Transactions

TBD

## Clusters

TBD

# SEE ALSO

There is another Perl6 Redis module
[`Redis`](https://github.com/cofyc/perl6-redis) that uses a Perl 6
implementation of the protocol so it doesn't depend on external
libraries like this module.  If you don't need the performance, it may
be easier to use.

# LICENSE

[Redis](https://redis.io), and the Redis logo are the trademarks of
Salvatore Sanfilippo in the U.S. and other countries.

[Eredis](https://github.com/EulerianTechnologies/eredis) is written
and maintained by Guillaume Fougnies and released under the BSD
license.

This software is released under the NASA-1.3 license.  See [NASA Open Source Agreement](../master/NASA_Open_Source_Agreement_1.3%20GSC-17829.pdf)

Copyright © 2017 United States Government as represented by the
Administrator of the National Aeronautics and Space Administration.
No copyright is claimed in the United States under Title 17,
U.S.Code. All Other Rights Reserved.
