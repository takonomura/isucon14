package Mojo::Isuride::Time;
use v5.40;
use utf8;

# Perlでミリ秒単位のUNIX時間を取得するユーティリティ
use Exporter 'import';

our @EXPORT_OK = qw(
    unix_milli_from_str
);

use Time::Moment;

# DateTime::Format::Strptimeの場合は以下のフォーマット
# use constant FORMAT_DATETIME => DateTime::Format::Strptime->new(
#     pattern   => '%Y-%m-%d %H:%M:%S.%3N',
#     time_zone => 'UTC',
# );

use constant FORMAT_TIME => qr/\A(\d{4})-(\d{2})-(\d{2}) (\d{2}):(\d{2}):(\d{2})\.(\d{1,9})/;

sub unix_milli_from_str ($str) {
    if ($str =~ FORMAT_TIME) {
        my ($year, $month, $day, $hour, $minute, $second, $fraction) = ($1, $2, $3, $4, $5, $6, $7);
        my $nanosecond = $fraction * (10**(9 - length($fraction)));
        my $tm         = Time::Moment->new(
            year       => $year,
            month      => $month,
            day        => $day,
            hour       => $hour,
            minute     => $minute,
            second     => $second,
            nanosecond => $nanosecond,
        );
        my $milliepoch = $tm->epoch * 1000 + $tm->millisecond;
        return $milliepoch;
    }
    die "Invalid time format: $str";
}

