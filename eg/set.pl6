use v6;

use Redis::Async;
use Redis::Objects;

my $redis = Redis::Async.new;

my $set = Redis::Set.new(:$redis, key => 'myset');

$set.push(^10);

say $set.keys;

say $set.elems;

say $set.values;

say $set.pick;

say $set.roll(10);

say $set.kv;

say $set.grab for ^3;

say $set.keys;

say 3 ∈ $set ?? "3 is a member" !! "3 is not a member";
