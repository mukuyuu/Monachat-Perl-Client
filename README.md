# Monachat-Perl-Client
Monachat Perl Client



Command list:

/name (name):  Name change.

/character (character code):
Character change.

/stat (status):
Status change.

/x (x):
Moves horizontally.

/y (y):
Moves vertically.

/scl:
Changes your direction.

/stalk (ID):
Stalk mode, follow the id provided across the room.

/antistalk (ID):
Antistalk mode, run away from the id provided across the room.

/search [username]:
In the case a username is provided, searchs that user through all the rooms, if not, just displays info on all the rooms.

/newinstance [here]:
In case here is provided, opens another instance in that room, if not, opens another instance in the main room.

/relogin [room]:
In case that proxy option is enabled, ID won't change if a room number is provided.

/disconnect:
Disconnects from the server.

/copy (ID):
Copies all the data from the provided ID.

/default:
Goes back to the default login data.



コマンドリスト：

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
