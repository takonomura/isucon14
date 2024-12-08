package Kossy::Isuride::Middleware;
use v5.40;
use utf8;
use HTTP::Status qw(:constants);
use Cpanel::JSON::XS::Type;

sub app_auth_middleware ($app) {
    sub ($self, $c) {
        my $access_token = $c->req->cookies->{app_session};

        unless ($access_token) {
            return $c->halt_json(HTTP_UNAUTHORIZED, 'app_session cookie is required');
        }

        my $user = $self->dbh->select_row(
            'SELECT * FROM users WHERE access_token = ?',
            $access_token
        );

        unless ($user) {
            return $c->halt_json(HTTP_UNAUTHORIZED, 'invalid access_token');
        }

        $c->stash->{user} = $user;
        return $app->($self, $c);
    };
}

sub owner_auth_middleware ($app) {
    sub ($self, $c) {
        my $access_token = $c->req->cookies->{owner_session};

        unless ($access_token) {
            return $c->halt_json(HTTP_UNAUTHORIZED, 'owner_session cookie is required');
        }

        my $owner = $self->dbh->select_row(
            'SELECT * FROM owners WHERE access_token = ?',
            $access_token
        );

        unless ($owner) {
            return $c->halt_json(HTTP_UNAUTHORIZED, 'invalid access_token');
        }

        $c->stash->{owner} = $owner;
        return $app->($self, $c);
    };
}

sub chair_auth_middleware ($app) {
    sub ($self, $c) {
        my $access_token = $c->req->cookies->{chair_session};

        unless ($access_token) {
            return $c->halt_json(HTTP_UNAUTHORIZED, 'chair_session cookie is required');
        }

        my $chair = $self->dbh->select_row(
            'SELECT * FROM chairs WHERE access_token = ?',
            $access_token
        );

        unless ($chair) {
            return $c->halt_json(HTTP_UNAUTHORIZED, 'invalid access_token');
        }

        $c->stash->{chair} = $chair;
        return $app->($self, $c);
    };
}

sub error_handling ($app) {
    sub ($self, $c) {
        try {
            $app->($self, $c);
        } catch ($e) {
            if ($e isa Kossy::Exception) {
                if ($e->{response}) {
                    die $e;
                }

                my $res = $c->render_json({ message => $e->{message} }, { message => JSON_TYPE_STRING });
                $res->status($e->{code});
                return $res;
            }
            my $res = $c->render_json({ message => $e }, { message => JSON_TYPE_STRING });
            $res->status(HTTP_INTERNAL_SERVER_ERROR);
            return $res;
        }
    }
}
