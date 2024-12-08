package Mojo::Isuride::Handler::Owner;
use v5.40;
use utf8;
use Time::Moment;
use experimental qw(defer);
no warnings 'experimental::defer';
use Mojo::Cookie::Response;

use HTTP::Status qw(:constants);
use Data::ULID::XS qw(ulid);
use Cpanel::JSON::XS::Type qw(
    JSON_TYPE_STRING
    JSON_TYPE_INT
    JSON_TYPE_INT_OR_NULL
    JSON_TYPE_BOOL
    json_type_arrayof
    json_type_null_or_anyof
);

use Mojo::Isuride::Time qw(unix_milli_from_str);
use Mojo::Isuride::Util qw(
    secure_random_str
    calculate_sale
    parse_int

    check_params
);

use constant OwnerPostOwnersRequest => {
    name => JSON_TYPE_STRING,
};

use constant OwnerPostOwnersResponse => {
    id                   => JSON_TYPE_STRING,
    chair_register_token => JSON_TYPE_STRING,
};

sub owner_post_owners ($c) {
    my $params = $c->req->json;
    my $db     = $c->mysql->db;

    unless (check_params($params, OwnerPostOwnersRequest)) {
        return $c->halt_json(HTTP_BAD_REQUEST, 'failed to decode the request body as json');
    }

    if ($params->{name} eq '') {
        return $c->halt_json(HTTP_BAD_REQUEST, 'some of required fields(name) are empty');
    }

    my $owner_id             = ulid();
    my $access_token         = secure_random_str(32);
    my $chair_register_token = secure_random_str(32);

    $db->query(
        'INSERT INTO owners (id, name, access_token, chair_register_token) VALUES (?, ?, ?, ?)',
        $owner_id,
        $params->{name},
        $access_token,
        $chair_register_token,
    );

    my $cookie = Mojo::Cookie::Response->new;
    $cookie->name('owner_session');
    $cookie->value($access_token);
    $cookie->path('/');
    $c->res->cookies($cookie);

    return $c->render_json(
        HTTP_CREATED,
        {
            id                   => $owner_id,
            chair_register_token => $chair_register_token,
        },
        OwnerPostOwnersResponse,
    );
}

use constant ChairSales => {
    id    => JSON_TYPE_STRING,
    name  => JSON_TYPE_STRING,
    sales => JSON_TYPE_INT,
};

use constant modelSales => {
    model => JSON_TYPE_STRING,
    sales => JSON_TYPE_INT,
};

use constant OwnerGetSalesResponse => {
    total_sales => JSON_TYPE_INT,
    chairs      => json_type_arrayof(ChairSales),
    models      => json_type_arrayof(modelSales),
};

sub owner_get_sales ($c) {
    my $since_tm = Time::Moment->from_epoch(0);

    if ($c->req->query_params->param('since')) {
        my ($parsed, $err) = parse_int($c->req->query_params->param('since'));

        if ($err) {
            return $c->halt_json(HTTP_BAD_REQUEST, 'invalid query parameter: since');
        }
        $since_tm = Time::Moment->from_epoch($parsed / 1000);
    }

    my $until_tm = Time::Moment->new(year => 9999, month => 12, day => 31, hour => 23, minute => 59, second => 59, nanosecond => 0);

    if ($c->req->query_params->param('until')) {
        my ($parsed, $err) = parse_int($c->req->query_params->param('until'));

        if ($err) {
            return $c->halt_json(HTTP_BAD_REQUEST, 'invalid query parameter: until');
        }
        $until_tm = Time::Moment->from_epoch($parsed / 1000);
    }

    my $owner = $c->stash('owner');
    my $db    = $c->mysql->db;
    my $txn   = $db->begin;

    my $chairs = $db->select_all('SELECT * FROM chairs WHERE owner_id = ?', $owner->{id});

    my $response_data = {
        total_sales => 0,
        chairs      => [],
    };

    my $model_sales_by_model = {};

    for my $chair ($chairs->@*) {
        my $rides = $db->select_all("SELECT rides.* FROM rides JOIN ride_statuses ON rides.id = ride_statuses.ride_id WHERE chair_id = ? AND status = 'COMPLETED' AND updated_at BETWEEN ? AND ? + INTERVAL 999 MICROSECOND",
            $chair->{id},
            $since_tm,
            $until_tm,
        );

        unless ($rides) {
            return $c->halt_json(HTTP_INTERNAL_SERVER_ERROR, 'failed to fetch rides');
        }

        my $chair_sales = sum_sales($rides);
        $response_data->{total_sales} += $chair_sales;

        push $response_data->{chairs}->@*, {
            id    => $chair->{id},
            name  => $chair->{name},
            sales => $chair_sales,
        };

        $model_sales_by_model->{ $chair->{model} } += $chair_sales;
    }

    my $models = [];

    for my ($model, $sales) ($model_sales_by_model->%*) {
        push $models->@*, {
            model => $model,
            sales => $sales,
        };
    }

    $response_data->{models} = $models;
    return $c->render_json(HTTP_OK, $response_data, OwnerGetSalesResponse);
}

sub sum_sales ($rides) {
    my $sale = 0;

    for my $ride (@$rides) {
        $sale += calculate_sale($ride);
    }
    return $sale;
}

use constant ChairWithDetail => {
    id                        => JSON_TYPE_STRING,
    owner_id                  => JSON_TYPE_STRING,
    name                      => JSON_TYPE_STRING,
    access_token              => JSON_TYPE_STRING,
    model                     => JSON_TYPE_STRING,
    is_active                 => JSON_TYPE_BOOL,
    created_at                => JSON_TYPE_INT,
    updated_at                => JSON_TYPE_INT,
    total_distance            => JSON_TYPE_INT,
    total_distance_updated_at => JSON_TYPE_INT,
};

use constant OwnerGetChairResponseChair => {
    id                        => JSON_TYPE_STRING,
    name                      => JSON_TYPE_STRING,
    model                     => JSON_TYPE_STRING,
    active                    => JSON_TYPE_BOOL,
    registered_at             => JSON_TYPE_INT,
    total_distance            => JSON_TYPE_INT,
    total_distance_updated_at => JSON_TYPE_INT_OR_NULL,
};

use constant OwnerGetChairResponse => {
    chairs => json_type_arrayof(OwnerGetChairResponseChair),
};

sub owner_get_chairs ($c) {
    my $owner  = $c->stash('owner');
    my $db     = $c->mysql->db;
    my $chairs = $db->select_all(<<~EOL
            SELECT id,
                   owner_id,
                   name,
                   access_token,
                   model,
                   is_active,
                   created_at,
                   updated_at,
                   IFNULL(total_distance, 0) AS total_distance,
                   total_distance_updated_at
            FROM chairs
                   LEFT JOIN (SELECT chair_id,
                                      SUM(IFNULL(distance, 0)) AS total_distance,
                                      MAX(created_at)          AS total_distance_updated_at
                               FROM (SELECT chair_id,
                                            created_at,
                                            ABS(latitude - LAG(latitude) OVER (PARTITION BY chair_id ORDER BY created_at)) +
                                            ABS(longitude - LAG(longitude) OVER (PARTITION BY chair_id ORDER BY created_at)) AS distance
                                     FROM chair_locations) tmp
                               GROUP BY chair_id) distance_table ON distance_table.chair_id = chairs.id
            WHERE owner_id = ?
    EOL
        , $owner->{id});

    unless (defined $chairs) {
        return $c->halt_json(HTTP_INTERNAL_SERVER_ERROR, 'failed to fetch chairs');
    }
    my $res = {};

    for my $chair ($chairs->@*) {
        my $ch = {
            id             => $chair->{id},
            name           => $chair->{name},
            model          => $chair->{model},
            active         => $chair->{is_active},
            registered_at  => unix_milli_from_str($chair->{created_at}),
            total_distance => $chair->{total_distance},
        };

        if (defined $chair->{total_distance_updated_at}) {
            $ch->{total_distance_updated_at} = unix_milli_from_str($chair->{total_distance_updated_at});
        }

        push $res->{chairs}->@*, $ch;
    }

    return $c->render_json(HTTP_OK, $res, OwnerGetChairResponse);
}
