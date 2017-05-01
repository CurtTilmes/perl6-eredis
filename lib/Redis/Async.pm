use v6;

use Eredis;

enum REDIS_COMMAND_TYPE <
    REDIS_COMMAND_WRITE
    REDIS_COMMAND_READ
    REDIS_COMMAND_BLOCKING
    REDIS_COMMAND_BINARY
    REDIS_COMMAND_CURSOR
    REDIS_COMMAND_MS
>;

my %commands =
    dump       => REDIS_COMMAND_BINARY,
    blpop      => REDIS_COMMAND_BLOCKING,
    brpop      => REDIS_COMMAND_BLOCKING,
    brpoplpush => REDIS_COMMAND_BLOCKING,
    scan       => REDIS_COMMAND_CURSOR,
    sscan      => REDIS_COMMAND_CURSOR,
    hscan      => REDIS_COMMAND_CURSOR,
    zscan      => REDIS_COMMAND_CURSOR,
    pexpireat  => REDIS_COMMAND_MS
;

class Redis::Cursor {
    has $.redis;
    has @.command;
    has @.args;

    has $.cursor;
    has @.values;
    has $!pair = @!command[0].decode.uc eq 'HSCAN'|'ZSCAN';

    method next() {
        while not @!values {
            return Nil if $!cursor.defined and $!cursor eq '0';

            $!cursor //= '0';

            my @ret = $!redis.cmd(|@!command, $!cursor.encode, |@!args).value;
            $!cursor = @ret[0];
            @!values = |@ret[1];
        }

        return $!pair ?? (@!values.shift => @!values.shift)
	              !! @!values.shift;
    }
}

class Redis::PubSub {
    has Eredis::Reader $.reader handles<cmd release>;

    method new(*@args, :$reader) {
        my @arglist = @args.map({ .Str.encode });
        $reader.clear;
        my $self = self.bless(reader => $reader);
        $self.cmd(|@arglist);
        return $self;
    }

    method message() {
        $!reader.reply_blocking.value
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
}

class Redis::Async does Associative {
    has Eredis $.eredis handles <host_add host_file retry
                                 write write_pending write-wait>;

    has Eredis::Reader $.reader handles <cmd append_cmd reply clear>;

    method new(*@servers) {
        my $eredis = Eredis.new;
        for @servers {
            my ($host, $port) = .split(':');
            $eredis.host_add($host, $port.Int);
        }

        start $eredis.run_thr;

        nextwith(:$eredis, reader => $eredis.reader);
    }

    method finish() {
        .release with $!reader;
        .shutdown with $!eredis;
        .free with $!eredis;
        $!reader = Nil;
        $!eredis = Nil;
    }

    method DESTROY() {
        self.finish;
    }

    method value(Bool :$bin) {
        self.reply.value(:$bin);
    }

    method timeout(Numeric $seconds) {
        $!eredis.timeout(Int($seconds*1000))
    }

    method blocking(*@args, Bool :$bin) {
        my @arglist = @args.map({ .Str.encode });
        my $reader = $!eredis.reader;
        LEAVE { $reader.release }
        $reader.cmd(|@arglist).value(:$bin);
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
              }).flat;
        )
    }

    method psubscribe(*@patterns) {
        Redis::PubSub.new('PSUBSCRIBE', |@patterns, reader => $!eredis.reader)
    }

    method subscribe(*@channels) {
        Redis::PubSub.new('SUBSCRIBE', |@channels, reader => $!eredis.reader)
    }

    method FALLBACK(*@args, Bool :$async, Bool :$pipeline, Bool :$bin is copy)
    {
        my $type = %commands{@args[0].lc} // REDIS_COMMAND_READ;

        $bin = True if $type == REDIS_COMMAND_BINARY;

        my @arglist = do for @args {
            when Blob    { $_ }

            when Str     { .encode }

            when $_ ~~ Instant && $type == REDIS_COMMAND_MS
                         { (.to-posix[0]*1000).Int.Str.encode }

            when Instant { .to-posix[0].Int.Str.encode }

            default      { .Str.encode }
        };

        if $type == REDIS_COMMAND_CURSOR
        {
            my @command = @args[0].uc eq 'SCAN'
                          ?? (@arglist.shift)
                          !! (@arglist.shift, @arglist.shift);

            return Redis::Cursor.new(redis => self,
                                     command => @command,
                                     args => @arglist);
        }

        return self.blocking(|@arglist) if $type == REDIS_COMMAND_BLOCKING;

        return self.write(|@arglist) if $async;

        return self.append_cmd(|@arglist) if $pipeline;

        return self.cmd(|@arglist).value(:$bin);
    }

    method AT-KEY($key)           { self.FALLBACK('GET', $key) }

    method EXISTS-KEY($key)       { self.FALLBACK('EXISTS', $key) }

    method DELETE-KEY($key)       { self.FALLBACK('DEL', $key) }

    method ASSIGN-KEY($key, $new) { self.FALLBACK('SET', $key, $new) }
}
