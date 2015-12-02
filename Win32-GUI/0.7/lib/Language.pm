package Language;
use Exporter;
use utf8;

@ISA = qw(Exporter);
@EXPORT = grep($_, keys %{__PACKAGE__."::"});

my $LANGUAGE = "main::LANGUAGE";
my ($name, $id, $trip, $ihash, $status, $x, $y, $scl, $room, $log, $filename, $command, $option,
 $roomswithusers, $minute, $second) =
("main::name", "main::id", "main::trip", "main::ihash", "main::status", "main::x", "main::y", "main::scl",
 "main::room", "main::log", "main::filename", "main::command", "main::option", "main::roomswithusers",
 "main::minute", "main::second");
my $error = "main::!";
my $roomdata = "main::roomdata";

sub NAME_TOO_LARGE {
    $$LANGUAGE eq "english"  ? "Name is too large.\n" :
    $$LANGUAGE eq "japanese" ? "名前が長すぎるです。\n" :
    undef;
}
sub STAT_TOO_LARGE {
    $$LANGUAGE eq "english"  ? "Status is too large.\n" :
    $$LANGUAGE eq "japanese" ? "ステータスが長すぎるです。\n" :
    undef;
}
sub STALK_ON {
    $$LANGUAGE eq "english"  ? "Stalk $1\n" :
    $$LANGUAGE eq "japanese" ? "ストーク $1。\n" :
    undef;
}
sub STALK_ID {
    $$LANGUAGE eq "english"  ? "Stalk id. $1\n" :
    $$LANGUAGE eq "japanese" ? "ストーク ID: $1。\n" :
    undef;
}
sub ANTISTALK_ON {
    $$LANGUAGE eq "english"  ? "Antistalk $1\n" :
    $$LANGUAGE eq "japanese" ? "アンチストーク $1。\n" :
    undef;
}
sub ANTISTALK_ID {
    $$LANGUAGE eq "english"  ? "Antistalk id $1\n" :
    $$LANGUAGE eq "japanese" ? "アンチストーク ID $1。\n" :
    undef;
}
sub PROXY_ON {
    $$LANGUAGE eq "english"  ? "Proxy $1\n" :
    $$LANGUAGE eq "japanese" ? "プロクシー $1。\n" :
    undef;
}
sub ANTIIGNORE_ON {
    $$LANGUAGE eq "english"  ? "Antiignore $1\n" :
    $$LANGUAGE eq "japanese" ? "対無視 $1。\n" :
    undef;
}
sub ANTIIGNORE_ID {
    $$LANGUAGE eq "english"  ? "Antiiginore id: $1\n" :
    $$LANGUAGE eq "japanese" ? "対無視 ID: $1。\n" :
    undef;
}
sub MUTE_ON {
    $$LANGUAGE eq "english"  ? "Mute $1\n" :
    $$LANGUAGE eq "japanese" ? "ミュート $1。\n" :
    undef;
}
sub MUTE_ID {
    $$LANGUAGE eq "english"  ? "id $1 has been mutted.\n" :
    $$LANGUAGE eq "japanese" ? "ID $1がミュートされた。\n" :
    undef;
}
sub UNMUTE_ID {
    $$LANGUAGE eq "english"  ? "id $1 has been unmutted.\n" :
    $$LANGUAGE eq "japanese" ? "ID $1がミュート解除された。\n" :
    undef;
}
sub ROOMINFO_ON {
    $$LANGUAGE eq "english"  ? "Room information $1\n" :
    $$LANGUAGE eq "japanese" ? "部屋情報 $1。\n" :
    undef;
}
sub POPUP_ON {
    $$LANGUAGE eq "english"  ? "Popup $1\n" :
    $$LANGUAGE eq "japanese" ? "ポップアップ $1。\n" :
    undef;
}
sub DEBUG_ON {
    $$LANGUAGE eq "english"  ? "Debug $1\n" :
    $$LANGUAGE eq "japanese" ? "デバッグ $1。\n" :
    undef;
}
sub TRIP_ERROR {
    $$LANGUAGE eq "english"  ? "Couldn\'t open trip.txt: $!\n" :
    $$LANGUAGE eq "japanese" ? "trip.txtが開けませんでした: $!\n" :
    undef;
}
sub TRIP_NOT_FOUND {
    $$LANGUAGE eq "english"  ? "Trip $$trip doesn\'t exist.\n" :
    $$LANGUAGE eq "japanese" ? "トリップ".$$trip."が存在しません。\n" :
    undef;
}
sub SAVELOG_ERROR {
    $$LANGUAGE eq "english"  ? "Couldn\'t save log $$filename: $!\n" :
    $$LANGUAGE eq "japanese" ? "ログ".$$log."が保存できませんでした: $!\n" :
    undef;
}
sub SAVELOG_SUCCESS {
    $$LANGUAGE eq "english"  ? "Log saved as $filename.\n" :
    $$LANGUAGE eq "japanese" ? "ログ".$$filename."が保存されました。\n" :
    undef;
}
sub NO_COMMAND {
    $$LANGUAGE eq "english"  ? "Command $$command not recognized.\n" :
    $$LANGUAGE eq "japanese" ? "コマンド".$$command."が認識できませんでした。\n" :
    undef;
}
sub SEARCH_ROOM {
    $$LANGUAGE eq "english"  ? "Room $$room:\n" :
    $$LANGUAGE eq "japanese" ? "部屋 $$room:\n" :
    undef;
}
sub SEARCH_USER_FOUND {
    $$LANGUAGE eq "english"  ? "User $$option{searchuser} found.\n" :
    $$LANGUAGE eq "japanese" ? "ユーザー".$$option{searchuser}."発見。\n" :
    undef;
}
sub SEARCH_USER_NUMBER {
    $$LANGUAGE eq "english"  ? "There are $$roomswithusers rooms with people:\n" :
    $$LANGUAGE eq "japanese" ? "人がいる部屋は".$$roomswithusers."あります:\n" :
    undef;
}
sub SEARCH_RESULT {
    $$LANGUAGE eq "english"  ? "room $$room: $$roomdata{$$room}$$option" :
    $$LANGUAGE eq "japanese" ? "部屋$$room: $$roomdata{$$room}人$$option" :
    undef;
}
sub TRIP_EMPTY {
    $$LANGUAGE eq "english"  ? "trip.txt is empty.\n" :
    $$LANGUAGE eq "japanese" ? "trip.txtが空っぽです。\n" :
    undef;
}
sub TRIP_NOT_ENABLED {
    $$LANGUAGE eq "english"  ? "Trip is not enabled in this instance." :
    $$LANGUAGE eq "japanese" ? "このインスタンスではトリップファイルが変更出来ません。" :
    undef;
}
sub DISCONNECT {
    $$LANGUAGE eq "english"  ? "Disconnected from server.\n" :
    $$LANGUAGE eq "japanese" ? "サーバーから切断した。\n" :
    undef;
}
sub RELOGIN {
    $$LANGUAGE eq "english"  ? "Disconnected from server, trying to relogin...\n" :
    $$LANGUAGE eq "japanese" ? "サーバーから切断した、ログイン中・・・\n" :
    undef;
}
sub UPTIME {
    $$LANGUAGE eq "english"  ? "Uptime $$minute m $$second s.\n" :
    $$LANGUAGE eq "japanese" ? "アップタイム: ".$$minute."分".$$second."秒。\n" :
    undef;
}
sub ROOM {
    $$LANGUAGE eq "english"  ? "ROOM $$room" :
    $$LANGUAGE eq "japanese" ? "部屋 $$room" :
    undef;
}
sub LOGGED_IN {
    $$LANGUAGE eq "english"  ? "Logged in, id=$1.\n\n" :
    $$LANGUAGE eq "japanese" ? "ログインしました。貴方のID: $1\n\n" :
    undef;
}
sub ENTER_ROOM_ID {
    $$LANGUAGE eq "english"  ? "User with id $1 entered this room.\n" :
    $$LANGUAGE eq "japanese" ? "ID $1を持っている謎の人がログインしました。\n" :
    undef;
}
sub UINFO {
    $$LANGUAGE eq "english"  ? "$1 id=$2\n" :
    $$LANGUAGE eq "japanese" ? "$1 ID: $2\n" :
    undef;
}
sub ROOM_USER {
    $$LANGUAGE eq "english"  ? "room $2 persons $1\n" :
    $$LANGUAGE eq "japanese" ? "部屋"."$2: $1人\n" :
    undef;
}
sub TITLE_ROOM {
    $$LANGUAGE eq "english"  ? "Monachat [room: $2 persons: $1]" :
    $$LANGUAGE eq "japanese" ? "もなちゃと [部屋$2: $1人]" :
    undef;
}
sub CHANGE_STAT {
    $$LANGUAGE eq "english"  ? "$$name$$trip$$ihash ($$id) changed his status to $$status\n" :
    $$LANGUAGE eq "japanese" ? "$$name$$trip$$ihash ($$id)が状態を".$$status."に変更しました。\n" :
    undef;
}
sub SET_X {
    $$LANGUAGE eq "english"  ? "$$name$$trip$$ihash ($$id) moved to x $$x\n" :
    $$LANGUAGE eq "japanese" ? "$$name$$trip$$ihash ($$id)がｘを".$$x."に変更しました。\n" :
    undef;
}
sub SET_Y {
    $$LANGUAGE eq "english"  ? "$$name$$trip$$ihash ($$id) moved to y $$y\n" :
    $$LANGUAGE eq "japanese" ? "$$name$$trip$$ihash ($$id)がｙを".$$y."に変更しました。\n" :
    undef;
}
sub SET_SCL {
    $$LANGUAGE eq "english"  ? "$$name$$trip$$ihash ($$id) moved to $$scl\n" :
    $$LANGUAGE eq "japanese" ? "$$name$$trip$$ihash ($id)が向けをを".$$scl."に変更しました。\n" :
    undef;
}
sub RIGHT {
    $$LANGUAGE eq "english"  ? "right" :
    $$LANGUAGE eq "japanese" ? "右" :
    undef;
}
sub LEFT {
    $$LANGUAGE eq "english"  ? "left" :
    $$LANGUAGE eq "japanese" ? "左" :
    undef;
}
sub SAITAMA {
    $$LANGUAGE eq "english"  ? "SAITAMA SAITAMA ($1) ($2)\n" :
    $$LANGUAGE eq "japanese" ? "さいたまさいたまー ($1) ($2)\n" :
    undef;
}
sub EXIT_ROOM {
    $$LANGUAGE eq "english"  ? "You exited the room.\n" :
    $$LANGUAGE eq "japanese" ? "退室しました.\n" :
    undef;
}
sub EXIT_ROOM_ID {
    $$LANGUAGE eq "english"  ? "$$name$$trip$$ihash ($$id) exited this room.\n" :
    $$LANGUAGE eq "japanese" ? "$$name$$trip$$ihash ($$id)が退室しました.\n" :
    undef;
}
sub TIMEOUT {
    $$LANGUAGE eq "english"  ? "Connection timeout...\n" :
    $$LANGUAGE eq "japanese" ? "タイムアウトでサーバーから切断しました。\n" :
    undef;
}
sub ENTER {
    $$LANGUAGE eq "english"  ? " has logged in.\n" :
    $$LANGUAGE eq "japanese" ? " がログインしました。\n" :
    undef;
}
sub IGNORE {
    $$LANGUAGE eq "english"  ? "ignored " :
    $$LANGUAGE eq "japanese" ? "を無視しました。\n" :
    undef;
}
sub NO_IGNORE {
    $$LANGUAGE eq "english"  ? "stopped ignoring " :
    $$LANGUAGE eq "japanese" ? "を無視解除しました。\n" :
    undef;
}
sub GA {
    $$LANGUAGE eq "english"  ? "GA" :
    $$LANGUAGE eq "japanese" ? "が" :
    undef;
}

1;
