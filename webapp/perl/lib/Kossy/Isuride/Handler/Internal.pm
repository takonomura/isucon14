package Kossy::Isuride::Handler::Internal;
use v5.40;
use utf8;

use HTTP::Status qw(:constants);

# このAPIをインスタンス内から一定間隔で叩かせることで、椅子とライドをマッチングさせる
sub internal_get_matching($app, $c) {
    # MEMO: 一旦最も待たせているリクエストに適当な空いている椅子マッチさせる実装とする。おそらくもっといい方法があるはず…
    my $ride = $app->dbh->select_row('SELECT * FROM rides WHERE chair_id IS NULL ORDER BY created_at LIMIT 1');

    unless (defined $ride) {
        return $c->halt_no_content(HTTP_NO_CONTENT);
    }

    my $matched;
    my $empty = false;

    for (1 .. 10) {
        $matched = $app->dbh->select_row('SELECT * FROM chairs INNER JOIN (SELECT id FROM chairs WHERE is_active = TRUE ORDER BY RAND() LIMIT 1) AS tmp ON chairs.id = tmp.id LIMIT 1');

        unless (defined $matched) {
            return $c->halt_no_content(HTTP_NO_CONTENT);
        }

        $empty = $app->dbh->select_one("SELECT COUNT(*) = 0 FROM (SELECT COUNT(chair_sent_at) = 6 AS completed FROM ride_statuses WHERE ride_id IN (SELECT id FROM rides WHERE chair_id = ?) GROUP BY ride_id) is_completed WHERE completed = FALSE", $matched->{id});

        if ($empty) {
            last;
        }
    }

    if (!$empty) {
        return $c->halt_no_content(HTTP_NO_CONTENT);
    }

    $app->dbh->query('UPDATE rides SET chair_id = ? WHERE id = ?', $matched->{id}, $ride->{id});

    return $c->halt_no_content(HTTP_NO_CONTENT);
}
