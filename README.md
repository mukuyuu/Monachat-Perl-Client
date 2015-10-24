# Monachat-Perl-Client
Monachat Perl Client


#What is Monachat Perl Client?

Monachat perl client is a port of the monachat chat program with extended capabilities, with a focus in anonimity and easy of use, although for the time being it only has a text interface.


#Install instructions

To install Monachat Perl Client you need to have perl installed in your system.
Monachat Perl Client uses various non-standard modules which can be installed from CPAN from cmd with:

cpan
install Encode Win32::GUI IO::Socket::Socks LWP::UserAgent


#Command list:

/name (NAME):
Change name to NAME.
/character (CHARACTER):
Change character to CHARACTER.
/stat (STATUS):
Change status to STATUS.
/x (X):
Moves horizontally.
/y (Y):
Moves vertically.
/scl:
Changes your direction.
/ignore (ID):
Ignores ID.
/antiignore (ID):
If ID ignores you, disconnects and logs in again.
/stalk (ID) [nomove]:
Automatically repeats al the comments and follows the provided ID across the room, with option [nomove] it just repeat the comments.
/antistalk (ID):
The inverse to stalk, if someone comes across you, the character automatically moves to evade being followed.
/search (main|all) [print]:
Main: Just has a look to the main room, then prints the user number of the rooms there are users.
All: First searchs the main room to obtain the rooms in which there are users, then enters each room, stores the user data in every room and then prints the results.
Print: Instead of showing the output in the log window, sends it as comments.
/newinstance [here]:
Opens another instance of Monachat Perl Client, in the case you're using a proxy be careful of not using the same that of the first instance.
Here: Opens another instance in the current room.
/reenter:
Exit and enters again in the same room.
/relogin [skip NUMBER]:
Disconnects and then log in again.
Skip: Skips the number of successful connections by proxy NUMBER times so that if there is an issue with one proxy, it goes to the next.
/disconnect:
Forces the server to disconnect. Be careful with it as it can cause the server to ban you.
/copy (ID):
Copies all the data from ID and reenters the room.
/default:
Goes back to default login data.


#Userdata class

This client uses encapsulation to store and obtain user information which are stored in objects shared accross threads, which are $logindata (which stores the initial configuration of login values and is untouched across the program) and $userdata (where are stored all the user data, included your own).

It is not recommended to modify directly logindata values as they could not be used to revert to the original login data.

Userdata class API:

In the case you are retrieving your own login data with $login, it is not neccesary to provide an ID to get functions.

set_name(NAME, ID), get_name(ID) :
Sets and returns a scalar containing name.
set_id(ID), get_id(ID):
Sets and returns a scalar containing login ID.
set_character(CHARACTER, ID), get_character(ID):
Sets and returns a scalar containing character.
set_status(STATUS, ID), get_status(ID) :
Sets and returns a scalar containing status.
set_trip(TRIP, ID), get_trip(ID) :
Sets and returns a scalar containing trip.
set_ihash(IHASH, ID), get_ihash(ID) :
Sets and returns a scalar containing ihash.
set_r(R, ID), get_r(ID) :
Sets and returns a scalar containing the red color.
set_g(G, ID), get_g(ID) :
Sets and returns a scalar containing the green color.
set_b(B, ID), get_b(ID) :
Sets and returns a scalar containing the blue color.
set_x(X, ID), get_x(ID) :
Sets and returns a scalar containing horizontal position.
set_y(Y, ID), get_y(ID) :
Sets and returns a scalar containing vertical position.
set_scl(SCL, ID), get_scl(ID) :
Sets and returns a scalar containing direction.
set_attrib(ATTRIB, ID), get_sttrib(ID) :
Sets and returns a scalar containing attribute.
set_ignore(IHASH, ID), get_ignore(IHASH, ID) :
Sets and returns 1 if ignored and 0 if not. ID is the one ignoring the IHASH.
set_antiignore(ID), get_antiignore(ID) :
Sets and returns 1 if you are ignored and 0 if not.
set_stalk(ID), get_stalk(ID) :
Sets an ID to be stalked and returns 1 if stalked and 0 if not.
set_antistalk(ID), get_antistalk(ID) :
Sets an ID to be antistalked and returns 1 if stalked and 0 if not.
get_data(ID) :
Returns an array containing [NAME,
get_data_by_ihash(IHASH) :
Returns a two-element array containing [NAME, ID] of IHASH.





#コマンドリスト：

/relogin (部屋)：
部屋ナンバーを入れた場合はIDを変更せずに部屋に入り直す、入れてない場合は強制的に切断させてサーバーに入り直す。
プロクシーを使っている場合はIPを変更して

/name (名前)：
名前変更。

/character (キャラコード)：
キャラ変更。

/stat (状態)：
状態変更。

/disconnect：
ログアウト。

/x (x)：
横変更。

/y (y)：
縦変更。

/scl：
向き変更。

/stalk (ID)：
ストーカーモード。入力されたIDの発言を繰り替えして、位置を変更すればその位置に移動される。

/antistalk (ID)：
アンチストーカーモード。入力されたIDが自分の位置に近くなったら遠い位置に移動される。

/search [ユーザーネーム]：
ユーザーのある部屋に移動して、その部屋のユーザーデータが出てくる。

/newinstance [here]：
もう一個のクライアントが実行される、hereを入力した場合は今いる部屋にログインされる。

/copy (ID)：
入力されたIDの持ち主のデータをコピーして部屋に入り直す。

/proxy [on/off]：
プロクシー設定。

/default：
元のログインデータに戻る。
