use v6;

use Eredis;

class Redis::Cursor {
    has $.redis;
    has @.command;
    has @.args;
    has Bool $.pair;

    has $.cursor;
    has @.values;

    method next() {
        while not @!values {
            return Nil if $!cursor.defined and $!cursor eq '0';

            $!cursor //= '0';

            my @ret = $!redis.reader.cmd(|@!command, $!cursor.encode, |@!args)
                      .value;

            $!cursor = @ret[0];
            @!values = |@ret[1];
        }

        return $!pair ?? (@!values.shift => @!values.shift)
	              !! @!values.shift;
    }
}

class Redis::PubSub {
    has Eredis::Reader $.reader;

    method new(*@args, :$reader) {
        my @arglist = @args.map({ .Str.encode });
        $reader.clear;
        $reader.cmd(|@arglist);
        self.bless(reader => $reader);
    }

    method message() {
        $!reader.reply-blocking.value
    }

    method subscribe(*@channels) {
        $!reader.cmd('SUBSCRIBE'.encode,
                     @channels.map({ .Str.encode }).flat).value
    }

    method unsubscribe(*@channels) {
        $!reader.cmd('UNSUBSCRIBE'.encode,
                     @channels.map({ .Str.encode }).flat).value
    }

    method psubscribe(*@patterns) {
        $!reader.cmd('PSUBSCRIBE'.encode,
                     @patterns.map({ .Str.encode }).flat).value
    }

    method punsubscribe(*@patterns) {
        $!reader.cmd('PUNSUBSCRIBE'.encode,
                     @patterns.map({ .Str .encode}).flat).value
    }

    method release() {
        .release with $!reader;
        $!reader = Nil;
    }

    method DESTROY() {
        self.release;
    }
}

class Redis::Async {...}

class Redis::List does Positional {
    has Redis::Async $.redis;
    has Str $.listkey;

    multi method elems() { $!redis.llen($!listkey) }

    multi method AT-POS($index) is rw {
        my $listkey := $!listkey;
        my $redis := $!redis;
        Proxy.new(
            FETCH => method () {
                $redis.lindex($listkey, $index)
            },
            STORE => method ($new) {
                die "Out of range" unless 0 <= $index < $redis.llen($listkey);
                $redis.lset($listkey, $index, $new)
            }
        )
    }

    multi method EXISTS-POS($index) {
        defined $!redis.lindex($!listkey, $index)
    }

    multi method DELETE-POS($index) { fail "Can't delete." }

    multi method pop() { $!redis.rpop($!listkey) }

    multi method push(*@values) { $!redis.rpush($!listkey, |@values); self }

    multi method shift() { $!redis.lpop($!listkey) }

    multi method unshift(*@values) { $!redis.lpush($!listkey, |@values); self }

    multi method Str() { $!redis.lrange($!listkey, 0, -1).join(' ') }

    multi method gist() {
        my @list = $!redis.lrange($!listkey, 0, 100);
        @list.push('...') if @list.elems >= 100;
        '(' ~ @list.join(' ') ~ ')'
    }
}

class Redis::Async does Associative {
    has Eredis $.eredis handles <host-add host-file retry max-readers
                                 write write-pending write-wait>;

    has %!readers;
    has $!readers-lock = Lock.new;

    method new(Int :$max-readers is copy, Numeric :$timeout, Int :$retries,
               Str :$host-file, *@servers) {
        my $eredis = Eredis.new;

        $max-readers //= %*ENV<RAKUDO_MAX_THREADS> // 16;

        $eredis.max-readers($max-readers);

        $eredis.timeout(Int($timeout*1000)) with $timeout;

        $eredis.retry($retries) with $retries;

        $eredis.host-file($host-file) with $host-file;

        for @servers {
            my ($host, $port) = .split(':');
            $eredis.host-add($host, $port.Int);
        }

        start $eredis.run-thr;

        nextwith(:$eredis);
    }

    method reader() {
        $!readers-lock.protect: { %!readers{$*THREAD.id} //= $!eredis.reader }
    }

    method finish() {
        .release for %!readers.values:delete;
        .shutdown with $!eredis;
        .free with $!eredis;
        $!eredis = Nil;
    }

    method DESTROY() {
        self.finish;
    }

    method value(Bool :$bin) {
        self.reader.reply.value(:$bin);
    }

    method timeout(Numeric $seconds) {
        $!eredis.timeout(Int($seconds*1000))
    }

    method append(|c) { self.FALLBACK('APPEND', |c) }  # override Any.append

    method keys(|c)   { self.FALLBACK('KEYS', |c) }    # override Any.keys

    method hgetall(|c) { %(self.FALLBACK('HGETALL', |c)) } # Return Hash

    method info(Str $section
                where * ~~ 'server'|'clients'|'memory'|'persistence'|'stats'|
                           'replication'|'cpu'|'commandstats'|'cluster'|
                           'keyspace'|'all'|'default' = 'default') {
        %(
             (do for self.FALLBACK('INFO', $section).split(/\r\n/,:skip-empty) {
                 next if /^\#/;
                 .split(':');
              }).flat
        )
    }

    method psubscribe(*@patterns) {
        Redis::PubSub.new('PSUBSCRIBE', |@patterns, reader => $!eredis.reader)
    }

    method subscribe(*@channels) {
        Redis::PubSub.new('SUBSCRIBE', |@channels, reader => $!eredis.reader)
    }

    method scan(Str $pattern?, Int $count?)
    {
        my @args = $pattern ?? ('MATCH'.encode, $pattern.encode) !! ();
        @args.push('COUNT'.encode, $count.Str.encode) if $count;

        Redis::Cursor.new(redis => self,
                          command => ('SCAN'.encode),
                          args => @args);
    }

    method sscan(Str $key, Str $pattern?, Int $count?)
    {
        my @args = $pattern ?? ('MATCH'.encode, $pattern.encode) !! ();
        @args.push('COUNT'.encode, $count.Str.encode) if $count;

        Redis::Cursor.new(redis => self,
                          command => ('SSCAN'.encode, $key.encode),
                          args => @args);
    }

    method hscan(Str $key, Str $pattern?, Int $count?)
    {
        my @args = $pattern ?? ('MATCH'.encode, $pattern.encode) !! ();
        @args.push('COUNT'.encode, $count.Str.encode) if $count;

        Redis::Cursor.new(redis => self, :pair,
                          command => ('HSCAN'.encode, $key.encode),
                          args => @args);
    }

    method zscan(Str $key, Str $pattern?, Int $count?)
    {
        my @args = $pattern ?? ('MATCH'.encode, $pattern.encode) !! ();
        @args.push('COUNT'.encode, $count.Str.encode) if $count;

        Redis::Cursor.new(redis => self, :pair,
                          command => ('ZSCAN'.encode, $key.encode),
                          args => @args);
    }

    method FALLBACK(*@args, Bool :$async, Bool :$pipeline, Bool :$bin)
    {
        my @arglist = do for @args {
            when Blob     { $_ }
            when Str      { .encode }
            when Instant  { .DateTime.posix.Str.encode }
            when DateTime { .posix.Str.encode }
            default       { .Str.encode }
        };

        return $!eredis.write(|@arglist) if $async;

        return self.reader.append-cmd(|@arglist) if $pipeline;

        self.reader.cmd(|@arglist).value(:$bin);
    }

    method AT-KEY($key) {
        self.FALLBACK('GET', $key);
    }

    method EXISTS-KEY($key) {
        self.FALLBACK('EXISTS', $key).Bool;
    }

    method DELETE-KEY($key) {
        LEAVE self.FALLBACK('DEL', $key);
        self.FALLBACK('GET', $key);
    }

    method ASSIGN-KEY($key, $new) {
        self.FALLBACK('SET', $key, $new);
        $new;
    }

    method list(Str:D $key) {
        Redis::List.new(redis => self, listkey => $key)
    }
}
