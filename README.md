# Monachat-Perl-Client
Monachat Perl Client


#What is Monachat Perl Client?

Monachat perl client is a port of the monachat chat program with extended capabilities and a focus in anonimity and easy of use, although for the time being it only has a text interface.


#Install instructions

To install Monachat Perl Client you need to have perl installed in your system.
Monachat Perl Client uses various non-standard modules which can be installed from CPAN with:

```
cpan
install Encode Win32::GUI IO::Socket::Socks LWP::UserAgent
```


#Command list:

* /name (NAME):<br>
Changes name to NAME.
* /character (CHARACTER):<br>
Changes character to CHARACTER.
* /stat (STATUS):<br>
Changes status to STATUS.
* /rgb R G B
Changes color to R G B
* /x (X):<br>
Moves horizontally.
* /y (Y):<br>
Moves vertically.
* /move (xX yY)<br>
Moves horizontally and vertically
* /scl:<br>
Changes your direction.
* /attrib<br>
Changes your attrib
* /ignore (ID):<br>
Ignores ID.
* /antiignore (on|off|ID):<br>
If ID ignores you, disconnects and logs in again.
* /stalk (on|off|ID) [nomove]:<br>
Automatically repeats al the comments and follows the provided ID across the room, with option [nomove] it just repeat the comments.
* /antistalk (on|off|ID):<br>
The inverse to stalk, if someone comes across you, the character automatically moves to evade being followed.
* /search (main|all|user USER) [print]:<br>
   main: Just has a look to the main room, then prints the user number of the rooms there are users.<br>
   all: First searchs the main room to obtain the rooms in which there are users, then enters each room, stores the user data in every room and then prints the results.<br>
   user : Searches for user USER across all rooms and then stops when USER is found
   print: Instead of showing the output in the log window, sends it as comments.<br>
* /newinstance [here] [number]:<br>
Opens another instance of Monachat Perl Client, in the case you're using a proxy be careful of not using the same that of the first instance.
  here: Opens another instance in the current room.
  number: Opens NUMBER instances of Monachat Perl Client.
* /reenter:<br>
Exit and enters again in the same room.
* /relogin [skip NUMBER]:<br>
Disconnects and then log in again.
    skip: Skips the number of successful connections by proxy NUMBER times so that if there is an issue with one proxy, it goes to the next.
* /disconnect:<br>
Forces the server to disconnect. Be careful with it as it can cause the server to ban you.
* /copy (ID):<br>
Copies all the data from ID and reenters the room.
* /invisible:<br>
Changes all user values to null
* /default:<br>
Goes back to default login data.
* /clear (screen|userdata):<br>
Clears log screen or all user data to free memory
* /nomovedata (on|off): <br>
If off, doesn't show anything about other peoples moves
* /shutup: <br>
SAITAMA SAITAMA
* /popup (on|off|TRIGER):<br>
Add TRIGGER to the list of popup triggers
* /open:<br>
Opens graphical interface
* /close:<br>
Closes graphical interface
* /backgroundcolor (#XXXXXX):<br>
Changes background color to hexadecimal #XXXXXX
* /getname (IHASH|ID):<br>
Searches trip.txt for an entry and shows it in screen
* /addname (ID) (NAME):<br>
Add name to the ihash of ID in trip.txt
* /getroom:<br>
Shows users in screen
* /save [NAME]:<br>
Saves the current log in LOG/NAME, if NAME is not provided, the filename is defaulted to the current room
* /exit:<br>
Exits Monachat Perl Client


#Userdata class

This client uses encapsulation to store and obtain user information which are stored in objects shared accross threads, which are $logindata (which stores the initial configuration of login values and is untouched across the program) and $userdata (where are stored all the user data, included your own).

It is not recommended to modify directly logindata values as they could not be used to revert to the original login data.

Userdata class API:

In the case you are retrieving your own login data with $logindata, it is not neccesary to provide an ID to get functions.

* set_name(NAME, ID) / get_name(ID) :<br>
Takes a NAME and ID as arguments and returns a scalar containing name.
* set_id(ID) / get_id(ID):<br>
Takes an ID as argument and returns a scalar containing login ID.
* set_character(CHARACTER, ID) / get_character(ID):<br>
Takes a CHARACTER and ID as arguments and returns a scalar containing character.
* set_status(STATUS, ID) / get_status(ID) :<br>
Takes a STATUS and ID as arguments and returns a scalar containing status.
* set_trip(TRIP, ID) / get_trip(ID) :<br>
Takes a TRIP as argument and returns a scalar containing trip.
* set_ihash(IHASH, ID) / get_ihash(ID) :<br>
Takes an IHASH and ID as arguments and returns a scalar containing ihash.
* set_r(R, ID) / get_r(ID) :<br>
Takes red (R) and ID as arguments and returns a scalar containing the red color.
* set_g(G, ID) / get_g(ID) :<br>
Takes green (G) and ID as arguments and returns a scalar containing the green color.
* set_b(B, ID) / get_b(ID) :<br>
Takes blue (B) and ID as arguments and returns a scalar containing the blue color.
* set_x(X, ID) / get_x(ID) :<br>
Takes X and ID as arguments and returns a scalar containing horizontal position.
* set_y(Y, ID) / get_y(ID) :<br>
Takes Y and ID as arguments and returns a scalar containing vertical position.
* set_scl(SCL, ID) / get_scl(ID) :<br>
Takes a direction (SCL) and ID as arugments and returns a scalar containing direction.
* set_attrib(ATTRIB, ID) / get_sttrib(ID) :<br>
Takes an attribute (ATTRIB) and ID as arguments and returns a scalar containing attribute.
* set_ignore(IHASH, ID) / get_ignore(IHASH, ID) :<br>
Takes an IHASH and ID as arguments and returns 1 if true and 0 if false. ID is the one ignoring the IHASH.
* set_antiignore(ID) / get_antiignore(ID) :<br>
Takes an ID as argument and returns 1 if true and 0 if false.
* set_stalk(ID) / get_stalk(ID) :<br>
Takes an ID as argument and returns 1 if true and 0 if false.
* set_antistalk(ID) / get_antistalk(ID) :<br>
Takes an ID as argument and returns 1 if true and 0 if not.
* set_data(NAME, ID, CHARACTER, STATUS, TRIP, IHASH, R, G, B, X, Y, SCL, ATTRIB) / get_data(ID) :<br>
Sets and returns an array containing [NAME, CHARACTER, STATUS, TRIP, IHASH, R, G, B, X, Y, SCL, ATTRIB].
* get_data_by_ihash(IHASH) :<br>
Returns a two-element array containing [NAME, ID] of IHASH.
* copy(ID, TARGETID):<br>
Takes an ID as argument and copies the data from that ID to TARGETID.
* default(OBJECT)
Takes a login object as an argument and copies the data.
* invisible
Sets all the values as undef.


#License

This program is free software: you can redistribute it and/or modify it under the terms of the GNU General Public License as published by the Free Software Foundation, either version 3 of the License, or (at your option) any later version.


#Author

American man...
For bugs and sugerencies please contact with nishinishi##9999 at gmail dot com (remove the #s).<br><br><br><br>



#Monachat Perl Client(MPC)とは

MPCはアノニミティーと使いやすさを考えて作られたもなちゃとのパールポートです。
* アノニミティーとはなんぞ？
もなちゃとで名前を変えてもクライアントを使っている人たちに認識されてしまう、そのために本当の名無しおになるためにプロクシー機能が入っている、つまり、入るまいにIP、そしてトリップが変わる。
* 使いやすさってなんぞ？
   もなちゃとは人が少ない、その上に時間帯によって人数がかなり変わるから何度も部屋を出てどこに人がいるのかを見回す必要があると思うあなたに: 簡単に検索できサーチ機能。
   あれ？この人は前話したことあまったく覚えていない。。。と思うあなたに: ＭＰＣはトリップを自動的にファイルに保存しているから誰もが前に使った名前が確かめれる
   ユーザーデータを変えたいけど毎回ログイン画面に戻るのはだるいと思うあなに: 簡単にユーザーデータが変更できるコマンド。
   キャラクタープレイをするのが好きだけど毎回毎回名前とキャラを変えるのは疲れると思うあなたに: プロファイル入れ替え機能。
   目が悪いあなたに: バックグラウンドと文字の色が変更でき機能。
   ぐへへ。。。ねこたそちゃんかわいいよねこたそちゃん。。。と思うあなたに: 簡単にほかのユーザーのデータをコピーしたり発言を繰り返したり追いかけたりできる機能。
   もなちゃとでユーザーが少ないからいつも見ていられるのがだるいと思うあなたに: 誰かがあなたが選んだ言葉を発言すればシステムポップアップが出る機能

とかいろいろ作成中。


#インストールする方法

MPCをインストールするにはパールをインストール必要がある、ネットにはいろんな無料なソフトがあるからこっちでは説明しないが検索すればすぐに出てくる。

パールをインストールすれば最初から入っていないモジュールがあるのでそのモジュールをインストールする必要がある。
そうするにはcmdに入って:

```
cpan
install Encode Win32::GUI IO::Socket::Socks LWP::UserAgent
```

を入力すればそのモジュールがインストールされる。

#コマンドリスト

* /name (名前):<br>
名前を変更する。
* /character (キャラクター):<br>
キャラクターを変更する。
* /stat (状態):<br>
状態を変更しする。
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
* /search (main|all|user USER) [print]:<br>
   main: メインでユーザーがいる部屋を検索する。<br>
   all: メインで検索してからそれぞれのユーザーがいた部屋を検索する。<br>
   user: そしてUSERがその部屋にいれば止まる。<br>
   print: ログにプリントする代わりにコメントする。<br>
* /newinstance [here] [NUMBER]:<br>
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
* /nomovedata (on|off): <br>
   他のユーザーが動いてもログに出ない。
* /shutup: <br>
さいたまさいたま
* /popup (on|off|TRIGGER):<br>
ポップアップトリガーのリストにTRIGGERを追加する。
* /open:<br>
グラフィカルインターフェースを開く。
* /close:<br>
グラフィカルインターフェースを閉じる。
* /backgroundcolor (#XXXXXX):<br>
バックグラウンドの色を#XXXXXXに変更する。
* /getname (IHASH|ID):<br>
trip.txtでIHASHを検索する。
* /addname (ID) (NAME):<br>
trip.txtでIDのihashにNAMEを追加する
* /getroom:<br>
現在ルームにいるユーザーを見せる。
* /save [NAME]:<br>
今のログをLOG/NAMEに保存する、NAMEがなければ現在いる部屋の番号か名前にデフォルトする。
* /exit:<br>
Monachat Perl Clientを出る

#ライセンス

This program is free software: you can redistribute it and/or modify it under the terms of the GNU General Public License as published by the Free Software Foundation, either version 3 of the License, or (at your option) any later version.


#作者

American man...
バッグがあればnishinishi##999 at gmail dot com（＃を消して）に連絡してください。
