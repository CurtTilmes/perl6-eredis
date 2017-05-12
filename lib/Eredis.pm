use v6;

use NativeCall;

constant LIBEREDIS = 'eredis'; # liberedis.so

enum EREDIS_RETURN ( EREDIS_ERRCMD => -2,
                     EREDIS_ERR    => -1,
                     EREDIS_OK     =>  0  );

enum REDIS_REPLY ( REDIS_REPLY_STRING  => 1,
                   REDIS_REPLY_ARRAY   => 2,
                   REDIS_REPLY_INTEGER => 3,
                   REDIS_REPLY_NIL     => 4,
                   REDIS_REPLY_STATUS  => 5,
                   REDIS_REPLY_ERROR   => 6  );

class X::Eredis is Exception
{
    has Str $.message;
}

sub argv(@args)
{
    my int32 $argc = @args.elems;
    my @argv := CArray[Pointer].new;
    my @argvlen := CArray[size_t].new;
    my $i = 0;
    for @args {
        @argv[$i] = nativecast(Pointer, $_);
        @argvlen[$i] = $_.bytes;
        $i++;
    }
    return ($argc, @argv, @argvlen);
}

class Eredis::Reply is repr('CStruct') {
    has int32 $.type;
    has longlong $.integer;
    has size_t $.len;
    has Pointer $.str;
    has size_t $.elements;
    has CArray[Pointer] $.element;

    sub eredis_reply_dump(Eredis::Reply)
        is native(LIBEREDIS) { * }

    sub eredis_reply_free(Eredis::Reply)
        is native(LIBEREDIS) { * }

    method dump() {
        eredis_reply_dump(self)
    }

    method free() {
        eredis_reply_free(self)
    }

    method type() returns REDIS_REPLY {
        REDIS_REPLY($!type)
    }

    method value(Bool :$bin) {
        fail X::Eredis.new(message => 'Timeout') unless self;

        given $!type {
            when REDIS_REPLY_STRING | REDIS_REPLY_STATUS {
                my $value = Blob.new(
                    nativecast(CArray[uint8], $!str)[0 ..^ $!len]
                );
                $bin ?? $value !! $value.decode;
            }

            when REDIS_REPLY_INTEGER { $!integer }

            when REDIS_REPLY_NIL     { Nil }

            when REDIS_REPLY_ERROR   {
                fail X::Eredis.new(message => Blob.new(
                    nativecast(CArray[uint8], $!str)[0 ..^ $!len]
                ).decode);
            }

            when REDIS_REPLY_ARRAY {
                do for 0..^ $!elements {
                    nativecast(Eredis::Reply, $!element[$_]).value(:$bin);
                }
            }
        }
    }
}

class Eredis::Reader is repr('CPointer') {
    sub eredis_r_cmd(Eredis::Reader, Str) returns Eredis::Reply
        is native(LIBEREDIS) { * }

    sub eredis_r_cmdargv(Eredis::Reader, int32, CArray[Pointer], CArray[size_t])
        returns Eredis::Reply is native(LIBEREDIS) {*}

    sub eredis_r_append_cmd(Eredis::Reader, Str) returns int32
        is native(LIBEREDIS) { * }

    sub eredis_r_append_cmdargv(Eredis::Reader, int32, CArray[Pointer],
                                CArray[size_t]) returns int32
        is native(LIBEREDIS) { * }

    sub eredis_r_subscribe(Eredis::Reader) returns Eredis::Reply
        is native(LIBEREDIS) { * }

    sub eredis_r_reply(Eredis::Reader) returns Eredis::Reply
        is native(LIBEREDIS) { * }

    sub eredis_r_reply_detach(Eredis::Reader) returns Eredis::Reply
        is native(LIBEREDIS) { * }

    sub eredis_r_clear(Eredis::Reader)
        is native(LIBEREDIS) { * }

    sub eredis_r_release(Eredis::Reader)
        is native(LIBEREDIS) { * }

    multi method cmd(Str:D $cmd) returns Eredis::Reply {
        my $reply = eredis_r_cmd(self, $cmd)
            or die X::Eredis.new(message => "Bad cmd($cmd)");
        return $reply;
    }

    multi method cmd(*@args) returns Eredis::Reply {
        my $reply = eredis_r_cmdargv(self, |argv(@args))
            or die X::Eredis.new(message => "Bad cmd(@args[].join(','))");
        return $reply;
    }

    multi method append-cmd(Str:D $cmd) {
        eredis_r_append_cmd(self, $cmd) == EREDIS_OK
            or die X::Eredis.new(message => "Bad append_cmd($cmd)");
    }

    multi method append-cmd(*@args) {
        eredis_r_append_cmdargv(self, |argv(@args)) == EREDIS_OK
            or die X::Eredis.new(message => "Bad append_cmd(@args[])");
    }

    method reply() returns Eredis::Reply {
        eredis_r_reply(self)
    }

    method subscribe() returns Eredis::Reply {
        eredis_r_subscribe(self)
    }

    method reply-detach() returns Eredis::Reply {
        eredis_r_reply_detach(self)
    }

    method clear() {
        eredis_r_clear(self);
    }

    method release() {
        eredis_r_release(self);
    }
}

class Eredis is repr('CPointer') {

    sub eredis_new() returns Eredis
        is native(LIBEREDIS) { * }

    sub eredis_host_add(Eredis, Str, int32) returns int32
        is native(LIBEREDIS) { * }

    sub eredis_host_file(Eredis, Str) returns int32
        is native(LIBEREDIS) { * }

    sub eredis_r(Eredis) returns Eredis::Reader
        is native(LIBEREDIS) { * }

    sub eredis_r_retry(Eredis, int32)
        is native(LIBEREDIS) { * }

    sub eredis_r_max(Eredis, int32)
        is native(LIBEREDIS) { * }

    sub eredis_run(Eredis) returns int32
        is native(LIBEREDIS) { * }

    sub eredis_run_thr(Eredis) returns int32
        is native(LIBEREDIS) { * }

    sub eredis_timeout(Eredis, int32)
        is native(LIBEREDIS) { * }

    sub eredis_w_cmd(Eredis, Str) returns int32
        is native(LIBEREDIS) { * }

    sub eredis_w_cmdargv(Eredis, int32, CArray[Pointer], CArray[size_t])
        returns int32 is native(LIBEREDIS) { * }

    sub eredis_w_pending(Eredis) returns int32
        is native(LIBEREDIS) { * }

    sub eredis_shutdown(Eredis)
        is native(LIBEREDIS) { * }

    sub eredis_free(Eredis)
        is native(LIBEREDIS) { * }

    method new() {
        eredis_new;
    }

    multi method host-add(Str:D $hostport) {
        my ($host, $port) = $hostport.split(':');
        samewith($host, $port.Int);
    }

    multi method host-add(Str:D $host, Int:D $port) {
        eredis_host_add(self, $host, $port) == EREDIS_OK
            or die X::Eredis.new(message => "host_add($host, $port) failed");
        return self;
    }

    method host-file(Str:D $filename) {
        eredis_host_file(self, $filename) != EREDIS_ERR
            or die X::Eredis.new(message => "host_file($filename) failed");
        return self;
    }

    method timeout(Int:D $timeout-ms) {
        eredis_timeout(self, $timeout-ms);
        return self;
    }

    method max-readers(Int:D $max-readers) {
        eredis_r_max(self, $max-readers);
        return self;
    }

    method retry(Int:D $retry) {
        eredis_r_retry(self, $retry);
        return self;
    }

    method reader() {
        eredis_r(self);
    }

    method run() {
        eredis_run(self);
    }

    method run-thr() {
        eredis_run_thr(self);
    }

    multi method write(Str:D $cmd) {
        eredis_w_cmd(self, $cmd) == EREDIS_OK
            or die X::Eredis.new(message => "write($cmd) failed");
    }

    multi method write(*@args) {
        eredis_w_cmdargv(self, |argv(@args)) == EREDIS_OK 
            or die X::Eredis.new(message => "write(@args[]) failed");
    }

    method write-pending() returns Int {
        eredis_w_pending(self);
    }

    method write-wait() {
        while eredis_w_pending(self) {}
    }

    method shutdown() {
        eredis_shutdown(self);
    }
    
    method free() {
        eredis_free(self);
    }
}
