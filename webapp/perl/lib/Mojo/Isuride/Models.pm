package Mojo::Isuride::Models;
use v5.40;
use utf8;

use Types::Standard -types;
use Cpanel::JSON::XS::Type qw(JSON_TYPE_STRING JSON_TYPE_INT JSON_TYPE_STRING_OR_NULL json_type_arrayof);

use Exporter 'import';

our @EXPORT_OK = qw(
    Coordinate
);

use constant ChairModel => {
    name  => Str,
    speed => Int,
};

use constant Chair => {
    id           => Str,
    owner_id     => Str,
    name         => Str,
    model        => Str,
    is_active    => Bool,
    access_token => Str,
    created_at   => Int,
    updated_at   => Int,
};

use constant Coordinate => {
    latitude  => JSON_TYPE_INT,
    longitude => JSON_TYPE_INT,
};
