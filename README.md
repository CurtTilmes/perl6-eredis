# Redis::Async - A high-performance client for Redis

This module includes bindings for the
[Eredis](https://github.com/EulerianTechnologies/eredis) client
library for [Redis](https://redis.io).

Eredis is a C client library built over Hiredis. It is lightweight,
high performance, reentrant and thread-safe.

## Basic Usage

    use Redis::Async;

    my $r = Redis::Async.new("localhost:6379");

    $r.set('foo', 'bar');

    say $r.get('foo'); # bar

## Notes

Case doesn't matter for commands `$r.GET` and `$r.get` are the same thing.

`$r.hgetall()` returns a `Hash`

`$r.info()` returns a `Hash`

`$r.expireat()` and `$r.pexpireat()` can take an `Instant` :

    $r.expireat('foo', now+5);  # same as $r.expire('foo', 5)

## Timeouts

You can set the Redis timeout with `$r.timeout($seconds)`.  You can
disable timeouts entirely with `$r.timeout(0)`. This is highly
recommended if you use blocking read requests, instead specify a
timeout with the command.  Timeouts should probably also be disabled
for publish/subscribe.

## Associative usage

*Redis::Async* also does the Associative role:

    $r<foo> = 'bar';

    say $r<foo> if $r<foo>:exists;

    $r<foo>:delete;

## Binary data

Strings are encoded as utf8 by default, but you can also pass in Blobs
of binary data.  Some commands like `RESTORE` require this.

Strings are also decoded as utf8 by default, you can request binary
values with the `:bin` flag.  It is enabled by default by `$r.dump`.

    say $r.get('foo', :bin);  # Blob:0x<62 61 72>

    my $x = $r.dump('foo');

    $r<foo>:delete;

    $r.restore('foo', 0, $x);

## Async writing

If you use the :async command, the write calls will be queued and sent
to the Redis server in the background, and the call will return
immediately.  This can dramatically speed up multiple writes.
You can wait for writes to complete with $r.write-wait.

    for ^100 { $r.set("key:$_", $_, :async) }
    $r.write-wait;

## Pipeline reads

You can also issue multiple reads without waiting for the replies,
then later read the replies.  This will pipeline the requests more
efficiently and speed up performance.

    for ^100 { $r.get("key:$_", :pipeline) }

    for ^100 { say $r.value }

## SCANing

The SCAN commands `SCAN`, `SSCAN`, `HSCAN`, `ZSCAN` return a
`Redis::Cursor` object that has a `.next` method to get the next
element.

    my $cursor = $r.scan('MATCH', "key:*"); 

    while $cursor.next -> $x {
        say "$x = $r{$x}";
    }

## Publish/Subscribe

The `SUBSCRIBE` commands return a `Redis::PubSub` object that can
read messages with .message:

    $r.timeout(0);
    my $sub = $r.subscribe('foo');

    while $sub.message -> @m {
        if @m[0] eq 'message' {
            say "Received message @m[2] on channel @m[1]";
        }
        last if @m[2] eq 'QUIT';
    }

## Transactions

TBI

# LICENSE

[Redis](https://redis.io), and the Redis logo are the trademarks of
Salvatore Sanfilippo in the U.S. and other countries.

[Eredis](https://github.com/EulerianTechnologies/eredis) is written
and maintained by Guillaume Fougnies and released under the BSD
license.

This software is released under the NASA-1.3 license.  See ...

Copyright © 2017 United States Government as represented by the
Administrator of the National Aeronautics and Space Administration.
No copyright is claimed in the United States under Title 17,
U.S.Code. All Other Rights Reserved.
