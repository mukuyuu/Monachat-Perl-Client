
# v0.9.3を使用するにはWWW::Shortenをインストールする必要があるので注意。

# Monachat Perl Client

#Monachat Perl Client(MPC)とは

MPCはアノニミティーと使いやすさを考えて作られたもなちゃとのパールポートです。
* アノニミティーとはなんぞ？<br>
もなちゃとで名前を変えてもクライアントを使っている人たちに認識されてしまう、そのために本当の名無しおになるためにプロクシー機能が入っている、つまり、入るまいにIP、そしてトリップが変わる。<br><br>

* 使いやすさってなんぞ？<br>
   もなちゃとは人が少ない、その上に時間帯によって人数がかなり変わるから何度も部屋を出てどこに人がいるのかを見回す必要があると思うあなたに:<br>
   簡単に検索できサーチ機能。<br><br>
   あれ？この人は前話したことあまったく覚えていない。。。と思うあなたに:<br> ＭＰＣはトリップを自動的にファイルに保存しているから誰もが前に使った名前が確かめれる機能。<br><br>
   ユーザーデータを変えたいけど毎回ログイン画面に戻るのはだるいと思うあなに:<br> 簡単にユーザーデータが変更できるコマンド。<br><br>
   いろんな部屋で同時に会話したいと思うあなたに:<br>
   プロクシー使ってれば何回でもクライアントが起動できる。<br><br>
   キャラクタープレイをするのが好きだけど毎回毎回名前とキャラを変えるのは疲れると思うあなたに:<br> プロファイル入れ替え機能。
   目が悪いあなたに: バックグラウンドと文字の色が変更でき機能。<br><br>
   ぐへへ。。。ねこたそちゃんかわいいよねこたそちゃん。。。と思うあなたに:<br> 簡単にほかのユーザーのデータをコピーしたり発言を繰り返したり追いかけたりできる機能。<br><br>
   もなちゃとでユーザーが少ないからいつも見ていられるのがだるいと思うあなたに:<br> 誰かがあなたが選んだ言葉を発言すればシステムポップアップが出る機能。<br><br>

とかいろいろ作成中。


#インストールする方法

MPCをインストールするにはパールをインストール必要がある、ネットにはいろんな無料なソフトがあるからこっちでは説明しないが検索すればすぐに出てくる。

パールをインストールすれば最初から入っていないモジュールがあるのでそのモジュールをインストールする必要がある。
そうするにはcmdに入って:

```
cpan
install Encode Win32::GUI IO::Socket::Socks LWP::UserAgent WWW::Shorten
```

を入力すればそのモジュールがインストールされる。

#コマンドリスト

* /name (名前):<br>
名前を変更する。
* /character (キャラクター):<br>
キャラクターを変更する。
* /stat (状態):<br>
状態を変更しする。
* /trip (トリップ):<br>
トリップをつける、トリップを消すには入りなおす必要がある。
* /x (横):<br>
横を変更しする。
* /y (縦):<br>
縦を変更しする。
* /move (x横 y縦):<br>
横と縦を変更しする。
* /rgb (R G B):<br>
色をR（赤）G（緑）B（青）に変更する。
* /scl:<br>
向きを変更しする。
* /ignore (ID):<br>
そっぽ見ういてIDを無視しする。ただしログ内ではまだ見える、名無しさん心が狭いです。
* /antiignore (on|off|ID):<br>
IDに無視されたら再ログインする。あまり使いすぎると怒こられちゃうぞ。
* /stalk (on|off|ID) [nomove]:<br>
自動的にIDの発言を繰り返してIDが移動すれば追いつく。
   nomove: 発言だけを繰り返す。
* /antistalk (on|off|ID):<br>
stalkの逆、誰かに追いつけられてれば自動的に移動する。
* /search (main|all|user USER):<br>
   main: メインでユーザーがいる部屋を検索する。<br>
   all: メインで検索してからそれぞれのユーザーがいた部屋を検索する。<br>
   user: そしてUSERがその部屋にいれば止まる。<br>
* /new [here] [NUMBER]:<br>
Monachat Perl Clientの新しいインスタンスを起動する。
  here: 現在いる部屋に新しいインスタンスを起動する。
  number: NUMBER回繰り返す。
* /reenter:<br>
部屋に入りなおす。
* /relogin [skip NUMBER]:<br>
ログアウトしてもなちゃとにつながりなおす。
   skip: 接続に成功すれば、NUMBER回繰り返す。問題がある特定のプロクシーがあれば次のプロクシーに移動できる。
* /disconnect:<br>
もなちゃとを強制的に切断させる、何度もやればBANになる可能性がある注意。
* /copy (ID):<br>
IDのデータをコピーして部屋に入りなおす。
* /invisible:<br>
透明になる
* /default:<br>
元のログインデータに戻る。
* /clear (screen|userdata):<br>
   screen: ログを削除する。
   userdata: $userdataを削除する。
* /mute (on|off|ID|com ID): <br>
   コメント以外に他のユーザーの行動が見えない。<br>
   com: そのユーザーのコメントが見えなくなるする（ただ画面に出ないだけで、無視はされない）。
* /profile (1,2,3...)
   プロファイルを変更して入りなおす。
* /end
   スクロールと問題がある場合はこのコマンドでログの最後まで行ける。
* /shutup: <br>
さいたまさいたまー。
* /popup (on|off|all|TRIGGER):<br>
ポップアップトリガーのリストにTRIGGERを追加する。<br>
all: すべてのコメントがポップアップで出てくる。
* /open:<br>
グラフィカルインターフェースを開く。
* /close:<br>
グラフィカルインターフェースを閉じる。
* /backgroundcolor (#XXXXXX):<br>
バックグラウンドの色を#XXXXXXに変更する。
* /language:<br>
言語を変更する（英語と日本語）。
* /getname (IHASH|ID):<br>
trip.txtでIHASHを検索する。
* /gettrip (IHASH|ID|name ID):<br>
getnameの逆、そのユーザーネームのトリップを検索して、またgetnameと同じように画面に表示する。
* /addname (ID) (NAME):<br>
trip.txtでIDのihashにNAMEを追加する
* /getroom:<br>
ルームにいるユーザーが表示される。
* /save [NAME]:<br>
今のログをLOG/NAMEに保存する、NAMEがなければ現在いる部屋の番号か名前にデフォルトする。
* /exit:<br>
Monachat Perl Clientを出る。

#コンフィグファイル
\[LOGIN DATA]:<br>
普通のログインデータのコンフィグ。<br><br>
\[PROFILE N]:<br>
[LOGIN DATA]と同じだが、パラメターの前にp1, p2, p3...がついている、いくつでも作成出来る。<br><br>
\[GRAPHIC OPTIONS]:<br>
graphicinterface = (0|1) : グラフィックインターフをオン、オフにする、この機能を使用するにはＳＤＬをインストールする必要がある。<br><br>
\[COLOR OPTIONS]:<br>
backgroundcolor = #RRGGBB: バックグランドの色を設定。<br><br>
[LOG OPTIONS]<br>
roominfo = (0|1): 人が出るまいにいちいち部屋の情報が表示されるかされないかを設定、デフォルトは０。<br><br>
[SOCKET OPTIONS]<br>
address = (IP): もなちゃとのデフォルトIPアドレス。<br>
port  = (PORT): 入口のポート。<br>
proxy = (yes|no): プロクシーをオン、オフにする。<br>
timeout = (n): タイアウトを設定する、プロクシーがどうしても見つからない場合はちょっと上げると見つかるかも、デフォルトは0.4。<br>
debug = (yes|no): デバッグモードをオン、オフにする。大体信号が表示されるだけ。<br>
change = (0|1): 再ログインするまいにIPが変わるかを設定、デフォルトは0。<br>
socksversion = (4|5): SOCKSバージョンを設定する、デフォルトは4。<br><br>
[CLIENT OPTIONS]<br>
language = (english|japanese): 言語を設定する、デフォルトは日本語。<br>
savetrip = (yes|no): トリップ保存機能をオン、オフにする、デフォルトは0。<br>
savelog = (0|1): もなちゃとを閉じればログが保存されるかを設定する、デフォルトは0.<br>
popup = (0|1): ポップアップ機能をオン、オフにする、デフォルトは０。<br>
trigger = (trigger1 : trigger2 : trigger3 : trigger4...): トリガーリスト。このリストに乗っている名前を誰かが発言すればポップアップがでてくる、triggerもオンになっていないと出てこない。

#ライセンス

This program is free software: you can redistribute it and/or modify it under the terms of the GNU General Public License as published by the Free Software Foundation, either version 3 of the License, or (at your option) any later version.


#作者

American man...
バグがあればnishinishi##999 at gmail dot com（＃を消して）に連絡してください。
