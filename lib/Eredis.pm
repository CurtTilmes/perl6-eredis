use v6;

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

use NativeCall;

sub argv(@args)
{
    my int32 $argc = @args.elems;
    my @argv := CArray[Str].new;
    my @argvlen := CArray[size_t].new;
    my $i = 0;
    for @args {
        @argv[$i] = $_;
        @argvlen[$i] = .encode('utf-8').bytes;  # This will probably bite me
        $i++;
    }
    return ($argc, @argv, @argvlen);
}

class Eredis::Reply is repr('CStruct') {
    has int32 $.type;
    has longlong $.integer;
    has size_t $.len;
    has Str $.str;
    has size_t $.elements;

    sub eredis_reply_dump(Eredis::Reply)
        is native(LIBEREDIS) { * }

    sub eredis_reply_free(Eredis::Reply)
        is native(LIBEREDIS) { * }

    sub eredis_reply_element(Eredis::Reply, int32) returns Eredis::Reply
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

    method value() {
        fail 'Timeout' unless self;
        given $!type {
            when REDIS_REPLY_STRING {
                return $!str;
            }
            when REDIS_REPLY_ARRAY {
                return do for 0 ..^ $.elements {
                    eredis_reply_element(self, $_).value;
                }
            }
            when REDIS_REPLY_INTEGER {
                return $!integer;
            }
            when REDIS_REPLY_NIL {
                return Nil;
            }
            when REDIS_REPLY_STATUS {
                return $.str;
            }
            when REDIS_REPLY_ERROR {
                fail $.str;
            }
        }
    }
}

class Eredis::Reader is repr('CPointer') {
    sub eredis_r_cmd(Eredis::Reader, Str) returns Eredis::Reply
        is native(LIBEREDIS) { * }

    sub eredis_r_cmdargv(Eredis::Reader, int32, CArray[Str], CArray[size_t])
        returns Eredis::Reply is native(LIBEREDIS) {*}

    sub eredis_r_append_cmd(Eredis::Reader, Str) returns int32
        is native(LIBEREDIS) { * }

    sub eredis_r_append_cmdargv(Eredis::Reader, int32, CArray[Str],
                                CArray[size_t]) returns int32
        is native(LIBEREDIS) { * }

    sub eredis_r_reply_blocking(Eredis::Reader) returns Eredis::Reply
        is native(LIBEREDIS) { * }

    sub eredis_r_reply(Eredis::Reader) returns Eredis::Reply
        is native(LIBEREDIS) { * }

    sub eredis_r_reply_detach(Eredis::Reader) returns Eredis::Reply
        is native(LIBEREDIS) { * }

    sub eredis_r_clear(Eredis::Reader)
        is native(LIBEREDIS) { * }

    sub eredis_r_release(Eredis::Reader)
        is native(LIBEREDIS) { * }

    multi method cmd(Str $cmd) returns Eredis::Reply {
        eredis_r_cmd(self, $cmd) or fail 'Bad Eredis reply';
    }

    multi method cmd(*@args) returns Eredis::Reply {
        eredis_r_cmdargv(self, |argv(@args));
    }

    multi method append_cmd(Str $cmd) returns EREDIS_RETURN {
        EREDIS_RETURN(eredis_r_append_cmd(self, $cmd))
    }

    multi method append_cmd(*@args) returns EREDIS_RETURN {
        EREDIS_RETURN(eredis_r_append_cmdargv(self, |argv(@args)))
    }

    method reply() {
        eredis_r_reply(self)
    }

    method reply_blocking() {
        eredis_r_reply_blocking(self)
    }

    method reply_detach() {
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

    sub eredis_run(Eredis) returns int32
        is native(LIBEREDIS) { * }

    sub eredis_run_thr(Eredis) returns int32
        is native(LIBEREDIS) { * }

    sub eredis_timeout(Eredis, int32)
        is native(LIBEREDIS) { * }

    sub eredis_w_cmd(Eredis, Str) returns int32
        is native(LIBEREDIS) { * }

    sub eredis_w_cmdargv(Eredis, int32, CArray[Str], CArray[size_t])
        returns int32 is native(LIBEREDIS) { * }

    sub eredis_w_pending(Eredis) returns int32
        is native(LIBEREDIS) { * }

    sub eredis_shutdown(Eredis)
        is native(LIBEREDIS) { * }

    sub eredis_free(Eredis)
        is native(LIBEREDIS) { * }

    method new(Str $server?) {
        my $self = eredis_new;

        with $server {
            my ($host, $port) = .split(':');
            $self.host_add($host, $port.Int)
                or die "Bad server $server";
        }

        $self;
    }

    method host_add(Str $host, int32 $port) returns Bool {
        eredis_host_add(self, $host, $port) == EREDIS_OK;
    }

    method host_file(Str $filename) returns Int {
        eredis_host_file(self, $filename);
    }

    method reader() {
        eredis_r(self);
    }

    method retry(Int $retry) {
        eredis_r_retry(self, $retry);
    }

    method run() {
        eredis_run(self);
    }

    method run_thr() {
        eredis_run_thr(self);
    }

    method timeout(Int $timeout) {
        eredis_timeout(self, $timeout);
    }

    multi method write(Str $cmd) {
        eredis_w_cmd(self, $cmd) == EREDIS_OK
            or fail 'Bad Eredis reply';;
    }

    multi method write(*@args) {
        eredis_w_cmdargv(self, |argv(@args)) == EREDIS_OK 
            or fail 'Bad Eredis reply';
    }

    method write_pending() {
        eredis_w_pending(self);
    }

    method write-wait() {
        while self.write_pending() {}
    }

    method shutdown() {
        eredis_shutdown(self);
    }
    
    method free() {
        eredis_free(self);
    }

    method DESTROY {
        eredis_free(self);
    }
}
