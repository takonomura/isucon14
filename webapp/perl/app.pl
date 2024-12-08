use v5.40;
use utf8;
use FindBin;
use lib "$FindBin::Bin/lib";

#  IsurideのMojolicious::Liteによる実装
#  Mojo::Isuride名前空間のpackageを利用する
#
#  Kossy による実装はapp.psgi を起動すること
#

use Mojolicious::Lite;
use Cpanel::JSON::XS;
use Cpanel::JSON::XS::Type;

use Mojo::mysql;
use Mojo::mysql::Database;

use HTTP::Status qw(:constants);
use Mojo::Isuride::Middleware;
use Mojo::Isuride::Handler::App;
use Mojo::Isuride::Handler::Owner;
use Mojo::Isuride::Handler::Chair;
use Mojo::Isuride::Handler::Internal;
use Mojo::Isuride::Util qw(check_params);

sub connect_db() {
    my $host     = $ENV{ISUCON_DB_HOST}     || '127.0.0.1';
    my $port     = $ENV{ISUCON_DB_PORT}     || '3306';
    my $user     = $ENV{ISUCON_DB_USER}     || 'isucon';
    my $password = $ENV{ISUCON_DB_PASSWORD} || 'isucon';
    my $dbname   = $ENV{ISUCON_DB_NAME}     || 'isuride';

    my $dsn   = "mysql://$user:$password\@$host:$port/$dbname";
    my $mysql = Mojo::mysql->new($dsn)->options({ mysql_enable_utf8mb4 => 1 });

    return $mysql;
}

# similar DBIx::Sunny
{
    *Mojo::mysql::Database::select_one = sub($self, @args) {
        $self->query(@args)->array->[0];
    };

    *Mojo::mysql::Database::select_row = sub($self, @args) {
        $self->query(@args)->hash;
    };

    *Mojo::mysql::Database::select_all = sub($self, @args) {
        $self->query(@args)->hashes;
    };
}

helper mysql => sub($c) {
    state $mysql = connect_db();
};

my $json_serializer = Cpanel::JSON::XS->new()->ascii(0)->utf8->allow_blessed(1)->convert_blessed(1);

helper render_json => sub {
    my ($c, $status, $data, $type) = @_;
    my $json_string = $json_serializer->encode($data, $type);
    app->renderer->respond($c, $json_string, 'json', $status);
};

helper halt_json => sub ($c, $status, $data) {
    return $c->render_json($status, { message => $data }, { message => JSON_TYPE_STRING });
};

helper halt_no_content => sub ($c, $status) {
    $c->res->headers->content_length(0);
    app->renderer->respond($c, '', 'text', $status);
};

# middlewares
use constant AppAuth   => \&Mojo::Isuride::Middleware::app_auth_middleware;
use constant OwnerAuth => \&Mojo::Isuride::Middleware::owner_auth_middleware;
use constant ChairAuth => \&Mojo::Isuride::Middleware::chair_auth_middleware;

sub handler (@funcs) {
    return sub($c) {
        try {
            $_->($c) for @funcs;
        } catch ($e) {
            if ($e isa Mojo::Exception) {
                $c->render_json(500, $e->to_string, JSON_TYPE_STRING);
            }
            $c->render_json(500, $e, JSON_TYPE_STRING);
        }
    };
}

sub app_handler   ($func) { handler(AppAuth,   $func) }
sub owner_handler ($func) { handler(OwnerAuth, $func) }
sub chair_handler ($func) { handler(ChairAuth, $func) }

# router
{
    post '/api/initialize' => handler(\&post_initialize);

    #  app handlers
    {
        post '/api/app/users' => handler(\&Mojo::Isuride::Handler::App::app_post_users);

        post '/api/app/payment-methods' => app_handler(\&Mojo::Isuride::Handler::App::app_post_payment_methods);
        get '/api/app/rides' => app_handler(\&Mojo::Isuride::Handler::App::app_get_rides);
        post '/api/app/rides'                     => app_handler(\&Mojo::Isuride::Handler::App::app_post_rides);
        post '/api/app/rides/estimated-fare'      => app_handler(\&Mojo::Isuride::Handler::App::app_post_rides_estimated_fare);
        post '/api/app/rides/:ride_id/evaluation' => app_handler(\&Mojo::Isuride::Handler::App::app_post_ride_evaluation);
        get '/api/app/notification'  => app_handler(\&Mojo::Isuride::Handler::App::app_get_notification);
        get '/api/app/nearby-chairs' => app_handler(\&Mojo::Isuride::Handler::App::app_get_nearby_chairs);
    }

    # chair handlers
    {
        post '/api/chair/chairs' => handler(\&Mojo::Isuride::Handler::Chair::chair_post_chairs);

        post '/api/chair/activity'   => chair_handler(\&Mojo::Isuride::Handler::Chair::chair_post_activity);
        post '/api/chair/coordinate' => chair_handler(\&Mojo::Isuride::Handler::Chair::chair_post_coordinate);
        get '/api/chair/notification' => chair_handler(\&Mojo::Isuride::Handler::Chair::chair_get_notification);
        post '/api/chair/rides/:ride_id/status' => chair_handler(\&Mojo::Isuride::Handler::Chair::chair_post_ride_status);
    }

    # owner handlers
    {
        post '/api/owner/owners' => handler(\&Mojo::Isuride::Handler::Owner::owner_post_owners);

        get '/api/owner/sales'  => owner_handler(\&Mojo::Isuride::Handler::Owner::owner_get_sales);
        get '/api/owner/chairs' => owner_handler(\&Mojo::Isuride::Handler::Owner::owner_get_chairs);
    }

    # internal handlers
    {
        get '/api/internal/matching' => handler(\&Mojo::Isuride::Handler::Internal::internal_get_matching);
    }
}

use constant PostInitializeRequest => {
    payment_server => JSON_TYPE_STRING,
};

use constant PostInitializeResponse => {
    language => JSON_TYPE_STRING,
};

sub post_initialize ($c) {
    my $params = $c->req->json;

    unless (check_params($params, PostInitializeRequest)) {
        return $c->halt_json(HTTP_BAD_REQUEST, 'failed to decode the request body as json');
    }

    if (my $e = system($FindBin::Bin . '/../sql/init.sh')) {
        return $c->halt_json(HTTP_INTERNAL_SERVER_ERROR, "failed to initialize: $e");
    }

    $c->mysql->db->query(
        q{UPDATE settings SET value = ? WHERE name = 'payment_gateway_url'},
        $params->{payment_server}
    );

    return $c->render_json(HTTP_OK, { language => 'perl' }, PostInitializeResponse);
}

app->start;
