package Mojo::Isuride::Util;
use v5.40;
use utf8;

use Exporter 'import';
use Carp qw(croak);

our @EXPORT_OK = qw(
    InitialFare
    FarePerDistance

    secure_random_str
    get_latest_ride_status
    calculate_distance
    calculate_fare
    calculate_sale

    parse_int

    check_params
);

use constant InitialFare     => 500;
use constant FarePerDistance => 100;

use Types::Standard -types;
use Cpanel::JSON::XS::Type;
use Type::Params qw(compile);
use Syntax::Keyword::Match;

use Scalar::Util qw(refaddr);
use Hash::Util qw(lock_ref_keys);
use Crypt::URandom ();

sub secure_random_str ($byte_length) {
    my $bytes = Crypt::URandom::urandom($byte_length);
    return unpack('H*', $bytes);
}

sub get_latest_ride_status ($c, $ride_id) {
    my $status = $c->mysql->db->select_one(
        q{SELECT status FROM ride_statuses WHERE ride_id = ? ORDER BY created_at DESC LIMIT 1},
        $ride_id
    );

    die 'sql: no rows in result set' unless $status;
    return $status;
}

# マンハッタン距離を求める
sub calculate_distance ($a_latitude, $a_longitude, $b_latitude, $b_longitude) {
    return abs($a_latitude - $b_latitude) + abs($a_longitude - $b_longitude);
}

sub abs ($n) {
    if ($n < 0) {
        return -$n;
    }
    return $n;
}

sub calculate_fare ($pickup_latitude, $pickup_longitude, $dest_latitude, $dest_longitude) {
    my $matered_dare = FarePerDistance * calculate_distance($pickup_latitude, $pickup_longitude, $dest_latitude, $dest_longitude);
    return InitialFare + $matered_dare;
}

sub calculate_sale ($ride) {
    return calculate_fare($ride->{pickup_latitude}, $ride->{pickup_longitude}, $ride->{destination_latitude}, $ride->{destination_longitude});
}

sub parse_int ($str) {
    my $is_valid = Int->check($str);
    return $str, !$is_valid;
}

# XXX: 以下はPerlでの型チェック支援用のユーティリティ
# 開発環境では、パラメータの型チェックを行う
use constant ASSERT => ($ENV{MOJO_MODE} || '') ne 'production';

# Cpanel::JSON::XS::Typeの型定義からType::Tinyの型定義を生成する
# 例: { a => JSON_TYPE_STRING, b => JSON_TYPE_INT } -> Dict[a => Str, b => Int]
# OR_NULLの型はOptional[]で表現する
sub _create_type_tiny_type_from_cpanel_type ($cpanel_structure) {
    if (my $type = _defined_cpanel_type_to_type_tiny_type($cpanel_structure)) {
        $type;
    }
    elsif (ref $cpanel_structure eq 'HASH') {
        Dict [ map { $_ => _create_type_tiny_type_from_cpanel_type($cpanel_structure->{$_}) } keys $cpanel_structure->%* ];
    }
    elsif (ref $cpanel_structure eq 'ARRAY') {
        ArrayRef [ map { _create_type_tiny_type_from_cpanel_type($_) } $cpanel_structure->@* ];
    }
    elsif ($cpanel_structure isa 'Cpanel::JSON::XS::Type::ArrayOf') {
        ArrayRef [ _create_type_tiny_type_from_cpanel_type($cpanel_structure->$*) ];
    }
    elsif ($cpanel_structure isa 'Cpanel::JSON::XS::Type::AnyOf') {
        defined $cpanel_structure->[0] && $cpanel_structure->[0] == JSON_TYPE_NULL ?
            Optional [ map { _create_type_tiny_type_from_cpanel_type($_) } grep { defined } $cpanel_structure->@[ 1 .. 2 ] ] :
            map { _create_type_tiny_type_from_cpanel_type($_) } grep { defined } $cpanel_structure->@[ 0 .. 2 ];
    }
    else {
        die "Unsupported type: $cpanel_structure";
    }
}

sub _defined_cpanel_type_to_type_tiny_type ($cpanel_type) {
    match($cpanel_type : ==) {
        case (JSON_TYPE_STRING) {
            Str;
        }
        case (JSON_TYPE_STRING_OR_NULL) {
            Optional [Str];
        }
        case (JSON_TYPE_INT) {
            Int;
        }
        case (JSON_TYPE_INT_OR_NULL) {
            Optional [Int];
        }
        case (JSON_TYPE_FLOAT) {
            Num;
        }
        case (JSON_TYPE_FLOAT_OR_NULL) {
            Optional [Num];
        }
        case (JSON_TYPE_BOOL) {
            Bool;
        }
        case (JSON_TYPE_BOOL_OR_NULL) {
            Optional [Bool];
        }
        default {
            undef;
        }
    }
}

my $compiled_checks = {};
my $compiled        = {};

sub check_params;
*check_params = ASSERT ? \&_check_params : sub { 1 };

sub _check_params ($params, $cpanel_type) {
    my $call_point = join '-', caller;

    unless ($compiled->{$call_point}) {
        my $type  = _create_type_tiny_type_from_cpanel_type($cpanel_type);
        my $check = compile($type);
        $compiled->{$call_point} = { check => $check, type => $type };
    }

    my $co    = $compiled->{$call_point};
    my $type  = $co->{type};
    my $check = $co->{check};

    try {
        my $flag = $check->($params);

        # 開発環境では、存在しないキーにアクセスした時にエラーになるようにしておく
        if (ASSERT && $flag) {
            lock_ref_keys($params, keys $cpanel_type->%*);
        }

        return 1;
    }
    catch ($e) {
        warn("Failed to check params: ", $type->get_message($params));
        warn("Checked params: ",         $params);
        warn("call point: ",             $call_point);

        return 0;
    }
}

1;
