package Mojo::Isuride::Payment::Gateway;
use v5.40;
use utf8;

use Exporter 'import';
use Carp qw(croak);

our @EXPORT_OK = qw(
    request_payment_gateway_post_payment
    PaymentGatewayErroredUpstream
);

use Mojo::Isuride::Util qw(check_params);

use HTTP::Status qw(:constants);
use Time::HiRes qw(sleep);
use Cpanel::JSON::XS qw(encode_json decode_json);
use Cpanel::JSON::XS::Type;
use Furl::HTTP;
use Types::Common -types;
use Type::Tiny;

use constant PaymentGatewayUnexpectedStatusCodeKind => Str & sub { $_ eq 'unexpected status code' };

use constant erroredUpstream                   => 'errored upstream';
use constant PaymentGatewayErroredUpstreamKind => Str & sub { $_ eq erroredUpstream };

use constant PaymentGatewayErroredUpstream => Dict [ kind => PaymentGatewayErroredUpstreamKind, message => Str ];

use constant PaymentGatewayPostPaymentRequest => {
    amount => JSON_TYPE_INT,
};

use constant PaymentGatewayPostPaymentResponseOne => {
    amount => JSON_TYPE_INT,
    status => JSON_TYPE_STRING,
};

sub request_payment_gateway_post_payment ($payment_gateway_url, $token, $param, $retrieve_rides_order_by_created_at_asc) {
    unless (check_params($param, PaymentGatewayPostPaymentRequest)) {
        return { status => 'failed to decode the request body as json' };
    }

    my $param_json = encode_json($param, PaymentGatewayPostPaymentRequest);

    # 失敗したらとりあえずリトライ
    # FIXME: 社内決済マイクロサービスのインフラに異常が発生していて、同時にたくさんリクエストすると変なことになる可能性あり

    my $retry = 0;

    while (1) {
        try {

            my $furl = Furl::HTTP->new(
                headers => [
                    'Content-Type'  => 'application/json',
                    'Authorization' => 'Bearer ' . $token,
                ],
            );
            my (undef, $status_code, undef, undef, undef) = $furl->request(
                method  => 'POST',
                url     => $payment_gateway_url . "/payments",
                content => $param_json,
            );

            if ($status_code != HTTP_NO_CONTENT) {
                # エラーが返ってきても成功している場合があるので、社内決済マイクロサービスに問い合わせ
                $furl = Furl::HTTP->new(
                    headers => [
                        'Authorization' => 'Bearer ' . $token,
                    ],
                );
                my (undef, $get_res_status_code, undef, undef, $get_res_body) = $furl->request(
                    method => 'GET',
                    url    => $payment_gateway_url . "/payments"
                );

                # GET /payments は障害と関係なく200が返るので、200以外は回復不能なエラーとする
                if ($get_res_status_code != HTTP_OK) {
                    die { message => '[GET /payments] unexpected status code (' . $get_res_status_code . ')' };
                }

                my $payments = decode_json($get_res_body);

                my $rides = $retrieve_rides_order_by_created_at_asc->();

                if (scalar $rides->@* != scalar $payments->@*) {
                    die { kind => erroredUpstream, message => "unexpected number of payments: " . scalar $rides->@* . " != " . scalar $payments->@* . '. ' . erroredUpstream };
                }
                return undef;
            }
            return undef;
        } catch ($e) {
            if ($retry < 5) {
                $retry++;
                sleep 0.1;
                next;
            } else {
                unless (ref $e eq 'HASH' && $e->{message}) {
                    return { message => $e };
                }
                return $e;
            }
        }
        last;
    }
    return undef;
}
