use v6;
use Test;

use String::CRC;

plan 1;

is crc16('foo'), 44950;

done-testing;
