use v5.40;
use FindBin;
use lib "$FindBin::Bin/lib";

#  IsurideのKossyによる実装
#  Kossy::Isuride名前空間のpackageを利用する
#
#  Mojolicious::Liteによる実装はapp.plを起動すること
#

use Plack::Builder;
use Kossy::Isuride::Web;
use File::Basename;

my $root_dir = File::Basename::dirname(__FILE__);

my $app = Kossy::Isuride::Web->psgi($root_dir);

builder {
    enable 'ReverseProxy';
    $app;
};
