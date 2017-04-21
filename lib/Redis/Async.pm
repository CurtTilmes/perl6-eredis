use v6;

use Eredis;

class Redis::Cursor {
    has $.redis;
    has @.command;
    has @.args;

    has $.cursor;
    has @.values;
    has $!pair = @!command[0] eq 'HSCAN'|'ZSCAN';

    method next() {
        while not @!values {
            return Nil if $!cursor.defined and $!cursor eq '0';

            my @ret = $!redis.cmd(|@!command, ($!cursor // '0'), |@!args).value;
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
        $reader.clear;
        my $self = self.bless(reader => $reader);
        $self.cmd(|@args);
        return $self;
    }

    method message() {
        $!reader.reply_blocking.value
    }

    method subscribe(*@channels) {
        $!reader.cmd('SUBSCRIBE', @channels.map({ .Str }).flat).value
    }

    method unsubscribe(*@channels) {
        $!reader.cmd('UNSUBSCRIBE', @channels.map({ .Str }).flat).value
    }

    method psubscribe(*@patterns) {
        $!reader.cmd('PSUBSCRIBE', @patterns.map({ .Str }).flat).value
    }

    method punsubscribe(*@patterns) {
        $!reader.cmd('PUNSUBSCRIBE', @patterns.map({ .Str }).flat).value
    }
}

class Redis::Async {
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

    method value() {
        self.reply.value
    }

    method timeout(Numeric $seconds) {
        $!eredis.timeout(Int($seconds*1000))
    }

    method command(*@args, Bool :$async = False, Bool :$pipeline = False) {
        my @str-args = @args.map({ .Str });
        return self.write(|@str-args) if $async;
        return self.append_cmd(|@str-args) if $pipeline;
        return self.cmd(|@str-args).value;
    }

    method blocking(*@args) {
        my @str-args = @args.map({ .Str });
        my $reader = $!eredis.reader;
        LEAVE $reader.release;
        $reader.cmd(|@str-args).value
    }

    method append($key, $value, Bool :$async, Bool :$pipeline) {
        self.command('APPEND', $key, $value, :$async, :$pipeline)
    }

    method auth(Str $password) {
        self.cmd('AUTH', $password).value;
    }

    method bgrewriteaof() {
        self.write('BGREWRITEAOF')
    }

    method bgsave() {
        self.write('BGSAVE')
    }

    method bitcount($key, Int $start?, Int $end = $start, Bool :$pipeline) {
        my @args = 'BITCOUNT', $key;
        @args.push($start, $end) with $start;
        self.command(|@args, :$pipeline);
    }

    method bitfield() {
        ...
    }

    method bitop(Str $op where $op ~~ 'AND'|'OR'|'XOR'|'NOT', *@keys,
                 Bool :$async, Bool :$pipeline) {
        self.command('BITOP', $op, |@keys, :$async, :$pipeline)
    }

    method bitpos($key, Int $bit where * ~~ 0|1, Int $start?, Int $end?,
                  Bool :$pipeline) {
        my @args = 'BITPOS', $key, $bit;
        @args.push($start) with $start;
        @args.push($end) with $end;
        self.command(|@args, :$pipeline)
    }

    method blpop(*@args) {
        self.blocking('BLPOP', |@args)
    }

    method brpop(*@args) {
        self.blocking('BRPOP', |@args)
    }

    method brpoplpush($source, $dest, Int $timeout) {
        self.blocking('BRPOPLPUSH', $source, $dest, $timeout)
    }

    method dbsize(Bool :$pipeline) {
        self.command('DBSIZE', :$pipeline)
    }

    method decr($key, Bool :$async, Bool :$pipeline) {
        self.command('DECR', $key, :$async, :$pipeline)
    }

    method decrby($key, Int $decrement, Bool :$async, Bool :$pipeline) {
        self.command('DECRBY', $key, $decrement, :$async, :$pipeline)
    }

    method del(*@keys, Bool :$async, :$pipeline) {
        self.command('DEL', |@keys, :$async, :$pipeline)
    }

#    method dump($key, :$pipeline) {
#        self.cmd('DUMP', $key);
#    }

    method echo(Str $message, Bool :$pipeline) {
	self.command('ECHO', $message, :$pipeline)
    }

    method exists(*@keys, Bool :$pipeline) {
        self.command('EXISTS', |@keys, :$pipeline)
    }

    method expire($key, Int $seconds, Bool :$async, Bool :$pipeline) {
        self.command('EXPIRE', $key, $seconds, :$async, :$pipeline)
    }

    method expireat($key, Instant $timestamp, Bool :$async, :$pipeline) {
        self.command('EXPIREAT', $key, $timestamp.to-posix[0].Int,
                     :$async, :$pipeline)
    }

    method flushall(:$async) {
        self.command('FLUSHALL', :$async)
    }

    method flushdb(:$async) {
        self.command('FLUSHDB', :$async)
    }

    method geoadd($key, *@args, :$async, :$pipeline) {
        self.command('GEOADD', $key, |@args, :$async, :$pipeline)
    }

    method geodist($key, *@args, :$pipeline) {
        self.command('GEODIST', $key, |@args, :$pipeline)
    }

    method geohash($key, *@members, :$pipeline) {
        self.command('GEOHASH', $key, |@members, :$pipeline)
    }

    method geopos($key, *@members, :$pipeline) {
        self.command('GEOPOS', $key, |@members, :$pipeline)
    }

    method georadius($key, *@args, :$pipeline) {
        self.command('GEORADIUS', $key, |@args, :$pipeline)
    }

    method georadiusbymember($key, *@args, :$pipeline) {
        self.command('GEORADIUSBYMEMBER', $key, |@args, :$pipeline)
    }

    method get($key, Bool :$pipeline) {
        self.command('GET', $key, :$pipeline)
    }

    method getbit($key, Int $offset, Bool :$pipeline) {
        self.command('GETBIT', $key, $offset, :$pipeline)
    }

    method getrange($key, Int $start, Int $end, :$pipeline) {
        self.command('GETRANGE', $key, $start, $end, :$pipeline)
    }

    method getset($key, $value, :$pipeline) {
        self.command('GETSET', $key, $value, :$pipeline)
    }

    method hdel($key, *@fields, Bool :$async, Bool :$pipeline) {
        self.command('HDEL', $key, |@fields, :$async, :$pipeline)
    }

    method hexists($key, $field, Bool :$pipeline) {
        self.command('HEXISTS', $key, $field, :$pipeline)
    }

    method hget($key, $field, Bool :$pipeline) {
        self.command('HGET', $key, $field, :$pipeline)
    }

    method hgetall($key, Bool :$pipeline) {
        %(self.command('HGETALL', $key, :$pipeline))
    }

    method hincrby($key, $field, Int $increment,
                   Bool :$async, Bool :$pipeline) {
        self.command('HINCRBY', $key, $field, $increment, :$async, :$pipeline)
    }

    method hincrbyfloat($key, $field, Numeric $increment,
                        Bool :$async, Bool :$pipeline) {
        self.command('HINCRBYFLOAT', $key, $field, $increment,
                     :$async, :$pipeline)
    }

    method hkeys($key, Bool :$pipeline) {
        self.command('HKEYS', $key, :$pipeline)
    }

    method hlen($key, Bool :$pipeline) {
        self.command('HLEN', $key, :$pipeline)
    }

    method hmget($key, *@fields, :$pipeline) {
        self.command('HMGET', $key, |@fields, :$pipeline)
    }

    method hmset($key, *@list, :$async, :$pipeline) {
        self.command('HMSET', $key, |@list, :$async, :$pipeline)
    }

    method hscan($key, $pattern?, Int :$count) {
        my @args;
        @args.push('MATCH', $pattern) if defined $pattern;
        @args.push('COUNT', $count) if defined $count;
        Redis::Cursor.new(redis => self, command => ('HSCAN', $key),
                          args => @args);
    }

    method hset($key, $field, $value, :$async, :$pipeline) {
        self.command('HSET', $key, $field, $value, :$async, :$pipeline)
    }

    method hsetnx($key, $field, $value, :$async, :$pipeline) {
        self.command('HSETNX', $key, $field, $value, :$async, :$pipeline)
    }

    method hstrlen($key, $field, :$pipeline) {
        self.command('HSTRLEN', $key, $field, :$pipeline)
    }

    method hvals($key, :$pipeline) {
        self.command('HVALS', $key, :$pipeline)
    }

    method incr($key, Bool :$async, Bool :$pipeline) {
        self.command('INCR', $key, :$async, :$pipeline)
    }

    method incrby($key, Int $increment, Bool :$async, Bool :$pipeline) {
        self.command('INCRBY', $key, $increment, :$async, :$pipeline)
    }

    method incrbyfloat($key, Numeric $increment,
                       Bool :$async, Bool :$pipeline) {
        self.command('INCRBYFLOAT', $key, $increment, :$async, :$pipeline)
    }

    method info(Str $section
                where * ~~ 'server'|'clients'|'memory'|'persistence'|'stats'|
                           'replication'|'cpu'|'commandstats'|'cluster'|
                           'keyspace'|'all'|'default' = 'default') {
        %(
             (do for self.cmd("INFO $section").value.split(/\r\n/,:skip-empty) {
                 next if /^\#/;
                 .split(':');
              }).flat;
        )
    }

    method lastsave(:$pipeline) {
        self.command('LASTSAVE', :$pipeline)
    }

    method lindex($key, Int $index, Bool :$pipeline) {
        self.command('LINDEX', $key, $index, :$pipeline)
    }

    method linsert($key, Str $where where * ~~ 'BEFORE'|'AFTER',
                   $pivot, $value, Bool :$async, Bool :$pipeline) {
        self.command('LINSERT', $key, $where, $pivot, $value,
                     :$async, :$pipeline)
    }

    method llen($key, Bool :$pipeline) {
        self.command('LLEN', $key, :$pipeline)
    }

    method lpop($key, Bool :$async, Bool :$pipeline) {
        self.command('LPOP', $key, :$async, :$pipeline)
    }        

    method lpush($key, *@values, Bool :$async, Bool :$pipeline) {
        self.command('LPUSH', $key, |@values, :$async, :$pipeline)
    }

    method lpushx($key, $value, Bool :$async, Bool :$pipeline) {
        self.command('LPUSHX', $key, $value, :$async, :$pipeline)
    }

    method lrange($key, Int $start = 0, Int $stop = -1, Bool :$pipeline) {
        self.command('LRANGE', $key, $start, $stop, :$pipeline)
    }

    method lrem($key, Int $count, $value, Bool :$async, Bool :$pipeline) {
        self.command('LREM', $key, $count, $value, :$async, :$pipeline)
    }

    method lset($key, Int $index, $value, Bool :$async, Bool :$pipeline) {
        self.command('LSET', $key, $index, $value, :$async, :$pipeline)
    }

    method ltrim($key, Int $start, Int $stop, Bool :$async, Bool :$pipeline) {
        self.command('LTRIM', $key, $start, $stop, :$async, :$pipeline)
    }

    method mset(*@key-values, *%pairs, Bool :$async, Bool :$pipeline) {
        self.command('MSET', (@key-values, %pairs.kv).flat, :$async, :$pipeline)
    }

    method msetnx(*@key-values, *%pairs, Bool :$async, Bool :$pipeline) {
        self.command('MSETNX', (@key-values, %pairs.kv).flat,
                     :$async, :$pipeline)
    }

    method move($key, Int $database, Bool :$async, :$pipeline) {
	self.command('MOVE', $key, $database, :$async, :$pipeline)
    }
    
    method persist($key, :$async, :$pipeline) {
        self.command('PERSIST', $key, :$async, :$pipeline)
    }

    method pexpire($key, Int $milliseconds, :$async, :$pipeline) {
        self.command('EXPIRE', $key, $milliseconds, :$async, :$pipeline)
    }

    method pexpireat($key, Instant $timestamp, :$async, :$pipeline) {
        
        self.command('PEXPIREAT', $key, ($timestamp.to-posix[0]*1000).Int,
                     :$async, :$pipeline)
    }

    method ping() {
        self.cmd('PING').value;
    }

    method psubscribe(*@patterns) {
        Redis::PubSub.new('PSUBSCRIBE', |@patterns, reader => $!eredis.reader)
    }

    method pttl($key, :$pipeline) {
        self.command('PTTL', $key, :$pipeline)
    }

    method publish($channel, $message, :$async, :$pipeline) {
        self.command('PUBLISH', $channel, $message, :$async, :$pipeline)
    }

    method quit() {
	self.cmd('QUIT').value
    }

    method randomkey($key, :$pipeline) {
        self.command('RANDOMKEY', $key, :$pipeline)
    }

    method rename($key, Str $newkey, :$async, :$pipeline) {
        self.command('RENAME', $key, $newkey, :$async, :$pipeline)
    }

    method renamenx($key, Str $newkey, :$async, :$pipeline) {
        self.command('RENAMENX', $key, $newkey, :$async, :$pipeline)
    }

    method rpop($key, :$async, :$pipeline) {
        self.command('RPOP', $key, :$async, :$pipeline)
    }

    method rpoplpush($source, $destination, :$pipeline) {
        self.command('RPOPLPUSH', $source, $destination, :$pipeline)
    }

    method rpush($key, *@values, :$async, :$pipeline) {
        self.command('RPUSH', $key, |@values, :$async, :$pipeline)
    }

    method rpushx($key, $value, :$async, :$pipeline) {
        self.command('RPUSHX', $key, $value, :$async, :$pipeline)
    }

#    method restore($key, Str $value, Int $pttl = 0, :$replace = False,
#        :$async, :$pipeline) {
#        my @args = 'RESTORE', $key, $pttl, $value;
#        @args.push('REPLACE') if $replace;
#        self.command(|@args, :$async, :$pipeline)
#    }

    method sadd($key, *@members, Bool :$async, Bool :$pipeline) {
	self.command('SADD', $key, |@members, :$async, :$pipeline)
    }

    method scan($pattern?, Int :$count) {
        my @args;
        @args.push('MATCH', $pattern) if defined $pattern;
        @args.push('COUNT', $count) if defined $count;
        Redis::Cursor.new(redis => self, command => ('SCAN'), args => @args);
    }

    method scard($key, Bool :$pipeline) {
	self.command('SCARD', $key, :$pipeline)
    }

    method sdiff(*@keys, Bool :$pipeline) {
	self.command('SDIFF', |@keys, :$pipeline)
    }
    
    method sdiffstore($destination, *@keys, Bool :$async, Bool :$pipeline) {
	self.command('SDIFFSTORE', $destination, |@keys, :$async, :$pipeline)
    }

    method setbit($key, Int $offset, Int $value where * ~~ 0|1,
                  Bool :$async, Bool :$pipeline) {
	self.command('SETBIT', $key, $offset, $value, :$async, :$pipeline)
    }

    method sinter(*@keys, Bool :$pipeline) {
	self.command('SINTER', |@keys, :$pipeline)
    }
    
    method sinterstore($destination, *@keys, Bool :$async, Bool :$pipeline) {
	self.command('SINTERSTORE', $destination, |@keys, :$async, :$pipeline)
    }

    method sismember($key, $member, Bool :$pipeline) {
	self.command('SISMEMBER', $key, $member, :$pipeline)
    }

    method smembers($key, Bool :$pipeline) {
	self.command('SMEMBERS', $key, :$pipeline)
    }

    method smove($source, $destination, $member,
		 Bool :$async, Bool :$pipeline) {
	self.command('SMOVE', $source, $destination, $member,
		     :$async, :$pipeline)
    }

    method spop($key, Bool :$async, Bool :$pipeline) {
	self.command('SPOP', $key, :$async, :$pipeline)
    }

    method srandmember($key, Int $count?, Bool :$pipeline) {
	my @args = 'SRANDMEMBER', $key;
	@args.push($count) with $count;
	self.command(|@args, :$pipeline)
    }

    method srem($key, *@members, Bool :$async, Bool :$pipeline) {
	self.command('SREM', $key, |@members, :$async, :$pipeline)
    }

    method sscan($key, $pattern?, Int :$count) {
        my @args;
        @args.push('MATCH', $pattern) if defined $pattern;
        @args.push('COUNT', $count) if defined $count;
        Redis::Cursor.new(redis => self, command => ('SSCAN', $key),
                          args => @args);
    }

    method sunion(*@keys, Bool :$pipeline) {
	self.command('SUNION', |@keys, :$pipeline)
    }

    method sunionstore($destination, *@keys, Bool :$async, Bool :$pipeline) {
	self.command('SUNIONSTORE', $destination, |@keys, :$async, :$pipeline)
    }
    
    method save() {
        self.cmd('SAVE').value
    }

    method select(Int $database) {
	self.cmd("SELECT $database").value
    }
    
    multi method set($key, $value, Numeric :$expire, Bool :$exists,
               Bool :$async, Bool :$pipeline) {
        my @args = 'SET', $key, $value;

        with $expire {
            if $expire == $expire.Int {
                @args.push('EX', $expire);
            } else {
                @args.push('PX', ($expire * 1000).Int);
            }
        }

        @args.push('XX') if defined $exists and $exists;

        @args.push('NX') if defined $exists and not $exists;

        self.command(|@args, :$async, :$pipeline)
    }

    method strlen($key, :$pipeline) {
        self.command('STRLEN', $key, :$pipeline)
    }

    method subscribe(*@channels) {
        Redis::PubSub.new('SUBSCRIBE', |@channels, reader => $!eredis.reader)
    }

    method swapdb(Int $db1, Int $db2) {
	self.cmd("SWAPDB $db1 $db2").value
    }

    method time() {
        self.cmd("TIME").value
    }

    method ttl($key, :$pipeline) {
        self.command('TTL', $key, :$pipeline)
    }

    method type($key, Bool :$pipeline) {
	self.command('TYPE', $key, :$pipeline)
    }

    method zadd($key, *@list, Bool :$async, Bool :$pipeline, ) {
	self.command('ZADD', $key, |@list, :$async, :$pipeline)
    }

    method zcard($key, Bool :$pipeline) {
	self.command('ZCARD', $key, :$pipeline)
    }

    method zcount($key, $min, $max, :$pipeline) {
	self.command('ZCOUNT', $key, $min, $max, :$pipeline)
    }

    method zincrby($key, $increment, $member, :$async, :$pipeline) {
	self.command('ZINCRBY', $key, $increment, $member, :$async, :$pipeline)
    }

    method zlexcount($key, $min, $max, :$pipeline) {
	self.command('ZLEXCOUNT', $key, $min, $max, :$pipeline)
    }

    method zrange($key, $start = 0, $stop = -1, Bool :$withscores = False,
		  Bool :$pipeline) {
	my @args = 'ZRANGE', $start, $stop;
	@args.push('WITHSCORES') if $withscores;
	self.command(|@args, :$pipeline)
    }

    method zrangebylex($key, $min, $max, $offset?, $count?, Bool :$pipeline) {
	my @args = 'ZRANGEBYLEX', $key, $min, $max;
	@args.push('LIMIT', $offset, $count) if defined $offset
	                                    and defined $count;
	self.command(|@args, :$pipeline)
    }

    method zrangebyscore($key, $min, $max, $offset?, $count?,
			 Bool :$withscores = False, Bool :$pipeline) {
	my @args = 'ZRANGEBYSCORE', $key, $min, $max;
	@args.push('WITHSCORES') if $withscores;
	@args.push('LIMIT', $offset, $count) if defined $offset
                                            and defined $count;
	self.command(|@args, :$pipeline)
    }

    method zrank($key, $member, Bool :$pipeline) {
	self.command('ZRANK', $key, $member, :$pipeline)
    }

    method zrem($key, *@members, Bool :$async, Bool :$pipeline) {
	self.command('ZREM', $key, |@members, :$async, :$pipeline)
    }

    method zremrangebylex($key, $min, $max, Bool :$async, Bool :$pipeline) {
	self.command('ZREMRANGEBYLEX', $key, $min, $max, :$async, :$pipeline)
    }

    method zremrangebyrank($key, $start, $stop, Bool :$async, Bool :$pipeline) {
	self.command('ZREMRANGEBYRANK', $key, $start, $stop,
		     :$async, :$pipeline)
    }

    method zremrangebyscore($key, $min, $max, Bool :$async, Bool :$pipeline) {
	self.command('ZREMRANGEBYSCORE', $key, $min, $max,
		     :$async, :$pipeline)
    }

    method zrevrange($key, $start, $stop, Bool :$withscores = False,
		     Bool :$pipeline) {
	self.command('ZREVRANGE', $key, $start, $stop, :$pipeline)
    }

    method zrevrangebylex($key, $max, $min, $offset?, $count?,
			  Bool :$pipeline) {
	my @args = 'ZREVRANGEBYLEX', $key, $max, $min;
	@args.push('LIMIT', $offset, $count) if defined $offset
                                            and defined $count;
	self.command(|@args, :$pipeline)
    }

    method zrevrangebyscore($key, $max, $min, $offset?, $count?,
			    Bool :$withscores = False, Bool :$pipeline) {
	my @args = 'ZREVRANGEBYSCORE', $key, $max, $min;
	@args.push('WITHSCORES') if $withscores;
	@args.push('LIMIT', $offset, $count) if defined $offset
                                            and defined $count;
	self.command(|@args, :$pipeline)
    }

    method zrevrank($key, $member, :$pipeline) {
	self.command('ZREVRANK', $key, $member, :$pipeline)
    }

    method zscan($key, $pattern?, Int :$count) {
        my @args;
        @args.push('MATCH', $pattern) if defined $pattern;
        @args.push('COUNT', $count) if defined $count;
        Redis::Cursor.new(redis => self, command => ('ZSCAN', $key),
                          args => @args);
    }
    
    method zscore($key, $member, :$pipeline) {
	self.command('ZSCORE', $key, $member, :$pipeline)
    }
}
