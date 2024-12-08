package Mojo::Isuride::Middleware;
use v5.40;
use utf8;
use HTTP::Status qw(:constants);
use Cpanel::JSON::XS::Type;

sub app_auth_middleware ($c) {
    my $access_token = $c->req->cookie('app_session')->value;

    unless ($access_token) {
        return $c->halt_json(HTTP_UNAUTHORIZED, 'app_session cookie is required');
    }

    my $user = $c->mysql->db->select_row(
        'SELECT * FROM users WHERE access_token = ?',
        $access_token
    );

    unless ($user) {
        return $c->halt_json(HTTP_UNAUTHORIZED, 'invalid access_token');
    }

    $c->stash(user => $user);
    return;
}

sub owner_auth_middleware ($c) {
    my $access_token = $c->req->cookie('owner_session')->value;

    unless ($access_token) {
        return $c->halt_json(HTTP_UNAUTHORIZED, 'owner_session cookie is required');
    }

    my $owner = $c->mysql->db->select_row(
        'SELECT * FROM owners WHERE access_token = ?',
        $access_token
    );

    unless ($owner) {
        return $c->halt_json(HTTP_UNAUTHORIZED, 'invalid access_token');
    }

    $c->stash(owner => $owner);
}

sub chair_auth_middleware ($c) {
    my $access_token = $c->req->cookie('chair_session')->value;

    unless ($access_token) {
        return $c->halt_json(HTTP_UNAUTHORIZED, 'chair_session cookie is required');
    }

    my $chair = $c->mysql->db->select_row(
        'SELECT * FROM chairs WHERE access_token = ?',
        $access_token
    );

    unless ($chair) {
        return $c->halt_json(HTTP_UNAUTHORIZED, 'invalid access_token');
    }

    $c->stash(chair => $chair);
}

