use v6;
use Test;
use Test::Redis;
use Redis::Async;

plan 35;

my $port = 16379;

my $redis will leave { .finish } = Test::Redis.new(:$port);
$redis.start;

my $r = Redis::Async.new("localhost:$port");

$r.timeout(0);

start {
    for 1..5 -> $val {
        is-deeply $r.brpop('mylist', 10),
                  ('mylist', $val.Str), "Got Value $val";
    }
}

for 1..5 -> $val {
    ok $r.lpush('mylist', $val), "Push Value $val";
    sleep .2;
}

start {
    for 1..5 -> $val {
        is-deeply $r.blpop('mylist', 10),
                  ('mylist', $val.Str), "Got Value $val";
    }
}

for 1..5 -> $val {
    ok $r.rpush('mylist', $val), "Push Value $val";
    sleep .2;
}

start {
    for 1..5 -> $val {
        my $res = $r.brpop('mylist2', 10);
        sleep .1;
        is-deeply $res, ('mylist2', $val.Str), "Got Value on list2 $val";
    }
}

start {
    for 1..5 -> $val {
        is $r.brpoplpush('mylist', 'mylist2', 10), $val.Str,
           "Moving $val from list to list2";
    }
}

for 1..5 -> $val {
    ok $r.lpush('mylist', $val), "Pushing $val onto first list";
    sleep .2;
}

done-testing;
