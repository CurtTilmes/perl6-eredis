use String::CRC;

class Redis::Cluster {
    method command($server, $command, $key, *@args) {
        my $reader = $.reader($server);
        my $cmd = ($command, $key, @args).join(' ');
        say "$server command [$cmd]";

        my $value = $reader.cmd($cmd).value;

        if $value ~~ Failure and
            $value.exception.message ~~ m:s/^MOVED (\d+) (.+\:\d+)$/ {
            return self.command($1.Str, $command, $key, |@args);
        }

        return $value;
    }
}
