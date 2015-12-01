# 食べログ や Retty のデータを引越しするやつ

## できること

* 食べログ のデータ(行きたい/行った)を吸い出す
* Retty のデータ(行きたい/行った)を吸い出す
* それらを 食べログ にアップロード

Retty にインポートしたい人は自分で search-rettyurl.pl と post-to-retty.pl 作ってください。

## ファイル

* preferences.pl 設定ファイル(要編集)
* fetch-list-retty.pl Retty のデータを吸い出す
* fetch-list-tabelog.pl 食べログ のデータを吸い出す
* translate-retty-list.pl 吸い出した Retty のデータを中間形式に変換
* translate-tabelog-list.pl 吸い出した 食べログ のデータを中間形式に変換
* search-tabelogurl.pl 中間形式データのうち、食べログのURLが欠けてるものを検索して埋める
* post-to-tabelog.pl 中間形式データを 食べログ にアップロード

## 必要なモジュール

* HTTP::Request
* JSON
* LWP::UserAgent
* URI::Query
* Web::Scraper
* YAML

## 使い方

### 設定

preferences.pl を編集する。

食べログや Retty にアクセスするためのクッキーをこのファイルに転記する必要があります、ブラウザの開発者向けツール（ブラウザの機能 or Firebug or LiveHTTPHeaders など）でヘッダ情報を見るか、ロケーションバーに alert(document.cookie) と入力するか、コンソールに document.cookie と入力するか、などで確認できると思います。

### 食べログから食べログに引越し(別のアカウントへ引っ越したい場合)

preferences.pl の fetch_tabelog_cookie と post_tabelog_cookie をそれぞれ引越し元、引っ越し先の有効なクッキーにしておく。（ログアウトすると無効になっちゃうので、別のブラウザでログインするか、もしくは吸い出し時に fetch_tabelog_cookie を設定してアップロード時に post_tabelog_cookie を設定する）

食べログからデータを吸い出す

    perl fetch-list-tabelog.pl > my-tabelog-exported.yml

データを変換する

    perl translate-tabelog-list.pl < my-tabelog-exported.yml > my-tabelog-translated.yml

データをアップロードする

    perl post-to-tabelog.pl < my-tabelog-translated.yml > my-tabelog-posted.yml

my-tabelog-posted.pl には送信した結果が保存されます。
エラーが起きて止まったら、原因を取り除いた後 my-tabelog-translated.yml から止まる前までのデータ（送信に成功したデータ）を削除してやりなおして下さい。

### Retty から 食べログに引越し

preferences.pl の fetch_retty_cookie と post_tabelog_cookie をそれぞれ引越し元、引っ越し先の有効なクッキーにしておく。 retty_user_id （数字）も指定する。

Rettyからデータを吸い出す

    perl fetch-list-retty.pl > my-retty-exported.yml

データを変換する

    perl translate-retty-list.pl < my-retty-exported.yml > my-retty-translated.yml

Rettyのデータのうち、食べログのURLが欠けているものについて検索を行う

    perl search-tabelogurl.pl < my-retty-translated.yml > my-retty-urlsearched.yml

複数のURLの候補があった場合は my-retty-urlsearched.yml の tabelogurl という項目にリストアップされるので、正しいもの以外を削除する（検索したURLの後に、 '#' に続けたコメントとして店名,エリア名,カテゴリ名が表示されるので、削除する際の参考にして下さい）。

データをアップロードする

    perl post-to-tabelog.pl < my-retty-urlsearched.yml > my-retty-posted.yml

my-tabelog-posted.pl には送信した結果が保存されます。
エラーが起きて止まったら、原因を取り除いた後 my-tabelog-translated.yml から止まる前までのデータ（送信に成功したデータ）を削除してやりなおして下さい。

