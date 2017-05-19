use v6;

use Redis::Async;

class Redis::List {...}

# This just pulls one at a time for now.  It should grab a chunk at a time..
class Redis::List::Iterator does Iterator
{
    has Redis::List $.list;
    has $.i = 0;

    method pull-one() { $!i == $!list.elems ?? IterationEnd !! $!list[$!i++] }
}

class Redis::List does Positional does Iterable {
    has Redis::Async $.redis;
    has Str $.key;

    method iterator() {
        Redis::List::Iterator.new(list => self)
    }

    method elems() { $!redis.llen($!key) }

    method keys() { Seq.new(Rakudo::Iterator.IntRange(0, self.elems - 1)) }

    method values() { Seq.new(self.iterator) }

    method kv() { Seq.new(Rakudo::Iterator.KeyValue(self.iterator)) }

    method pairs() { Seq.new(Rakudo::Iterator.Pair(self.iterator)) }

    method antipairs() { Seq.new(Rakudo::Iterator.AntiPair(self.iterator)) }

    method invert() { Seq.new(Rakudo::Iterator.Invert(self.iterator)) }

    method tail(Int(Cool) $number = 1)
    {
        my $start = max 0, self.elems - $number;
        return Seq.new unless 0 <= $start < self.elems;

        Seq.new(Redis::List::Iterator.new(list => self, i => $start))
    }

    method AT-POS($index) is rw {
        my $key := $!key;
        my $redis := $!redis;
        Proxy.new(
            FETCH => method () {
                $redis.lindex($key, $index)
            },
            STORE => method ($new) {
                die "Out of range" unless 0 <= $index < $redis.llen($key);
                $redis.lset($key, $index, $new);
                $new
            }
        )
    }

    method EXISTS-POS($index) {
        defined $!redis.lindex($!key, $index)
    }

    method DELETE-POS($index) { fail "Can't delete." }

    method pop() { $!redis.rpop($!key) }

    method push(*@values) { $!redis.rpush($!key, |@values); self }

    method shift() { $!redis.lpop($!key) }

    method unshift(*@values) { $!redis.lpush($!key, |@values); self }

    multi method Str() { $!redis.lrange($!key, 0, -1).join(' ') }

    multi method gist() {
        my @list = $!redis.lrange($!key, 0, 100);
        @list.push('...') if @list.elems >= 100;
        '(' ~ @list.join(' ') ~ ')'
    }
}

class Redis::Hash does Associative does Iterable {
    has Redis::Async $.redis;
    has Str $.key;

    method iterator() { $!redis.hscan($!key) }

    method elems() { $!redis.hlen($!key) }

    method kv() {
        Seq.new(Redis::Cursor.new(:$!redis,
                                  command => ('HSCAN'.encode, $!key.encode)))
    }

    method keys() { $!redis.hkeys($!key) }

    method values() { $!redis.hvals($!key) }

    method pairs() { Seq.new(self.iterator) }

    method AT-KEY($field) {
        my $key := $!key;
        my $redis := $!redis;
        Proxy.new(
            FETCH => method () {
                $redis.hget($key, $field)
            },
            STORE => method ($new) {
                $redis.hset($key, $field, $new);
                $new
            }
        )
    }

    method EXISTS-KEY($field) { $!redis.hexists($!key, $field).Bool }

    method DELETE-KEY($field) {
        LEAVE $!redis.hdel($!key, $field);
        $!redis.hget($!key, $field);
    }

    method ASSIGN-KEY($field, $new) {
        $!redis.hset($!key, $field, $new);
        $new;
    }
}

class Redis::Set does Iterable {
    has Redis::Async $.redis;
    has Str $.key;

    method iterator { $!redis.sscan($!key) }

    method push(*@values) { $!redis.sadd($!key, |@values); self }

    method elems() { $!redis.scard($!key) }

    method total() { $!redis.scard($!key) }

    method keys() { Seq.new(self.iterator) }

    method values() { True xx self.elems }

    method kv() { (self.keys Z self.values).flat }

    method pick($count = 1) { $!redis.srandmember($!key, $count) }

    method roll($count = 1) { $!redis.srandmember($!key, -$count) }

    method grab($count = 1) { $count == 1 ?? $!redis.spop($!key)
                                          !! $!redis.spop($!key, $count) }
}
