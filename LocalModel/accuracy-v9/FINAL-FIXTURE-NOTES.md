# v9 最終固定評価24文の作成記録

- 推論固定後に別担当が作成した自作小標本。母集団を代表するベンチマークではありません。
- 予測結果・推論ソース・モデル語彙を閲覧せず作成。推論は実行していません。ハッシュ算出のみソース/モデルのバイト列を読みました。
- 文頭英語→日本語20文（lowercase 5、Titlecase 5、acronym 5、比較的珍しい語/製品名 5）、純英語4文。未知語かどうかはモデル語彙を見ていないので未確認です。
- 日英境界に補助空白なし。英語フレーズ内の空白はEnglish側に含みます。1文ごとの確定を想定しています。
- schemaのみv8既存fixtureの先頭1件で確認。development28はrawの重複確認だけに使用し、重複0件でした。
- 24文を目視で二度確認し、各英語綴り・日本語読み・助詞境界を確認しました。保存済みrangeから著者の分節へ独立に再構成し、ASCII、全coverage、重複/空隙なし、0-based半開区間も検証しました。
- 著者スクリプト実行前後で下記3ファイルのSHAが同一です。

## 推論固定SHA256

- `18d52b77ea308961c155e897cc7b6a9259c1e2b03a4e5dbc51807e410e0fe892` `Core/Sources/Core/InputUtils/LocalLanguageRouter.swift`
- `5266c41a35edeff07c611e551de8e63de3cf4a65161c70d1ab7a415d5e850864` `Core/Sources/Core/InputUtils/LocalMixedSegmenter.swift`
- `e39825afc0a3badfc6e613d05fa600b7d0d0267816e46c45835e916f0dc9a69d` `Core/Sources/Core/Resources/LocalLanguageModel.json`

評価fixture SHA256: `22fc4dcfd9615ce840c079e5aa9022c144ddb51b59c24840b09a83abecd97d7b`

## 全分節（EN | JP）

01. `calendar` | `niashitanoyoteiwoiretekudasai` — calendarに明日の予定を入れてください
02. `headphone` | `wokabanniireta` — headphoneを鞄に入れた
03. `backup` | `gaowattarakonopasokonwokesu` — backupが終わったらこのパソコンを消す
04. `screen sharing` | `wohajimerumaenimadowotojiteokou` — screen sharingを始める前に窓を閉じておこう
05. `meeting room` | `nisaifuwowasuretekita` — meeting roomに財布を忘れてきた
06. `Spotify` | `dekinounokyokuwomouichidokikitai` — Spotifyで昨日の曲をもう一度聴きたい
07. `Firefox` | `wotojitemoongakuganatteiru` — Firefoxを閉じても音楽が鳴っている
08. `Dropbox` | `nikazokunoshashinwomatometeoita` — Dropboxに家族の写真をまとめておいた
09. `Google Maps` | `deekimadenomichiwoshirabeta` — Google Mapsで駅までの道を調べた
10. `Apple Music` | `nokinoutsukuttarisutowokikitai` — Apple Musicの昨日作ったリストを聴きたい
11. `PDF` | `wobetsunoforudanikopiishitekudasai` — PDFを別のフォルダにコピーしてください
12. `USB` | `gasasattamamaninatteiru` — USBが挿さったままになっている
13. `DNS` | `nosetteiwomotonimodoshita` — DNSの設定を元に戻した
14. `HDMI` | `nokeeburugamijikasugita` — HDMIのケーブルが短すぎた
15. `CPU fan` | `nootogakinouyoriookii` — CPU fanの音が昨日より大きい
16. `paperless` | `nishitakuteatarashiisukyannawokatta` — paperlessにしたくて新しいスキャナを買った
17. `microblog` | `nimaiasashashinwoageteiru` — microblogに毎朝写真を上げている
18. `Readwise` | `nikinounomemowonokoshiteoita` — Readwiseに昨日のメモを残しておいた
19. `Obsidian Sync` | `gasumumadekonomamahouchishiteokou` — Obsidian Syncが済むまでこのまま放置しておこう
20. `deskmat` | `wosentakushitakedomadakawakanai` — deskmatを洗濯したけどまだ乾かない
21. `Please send the meeting notes before lunch.` | `` — Please send the meeting notes before lunch.
22. `The new keyboard feels much quieter.` | `` — The new keyboard feels much quieter.
23. `I saved a copy in the shared folder.` | `` — I saved a copy in the shared folder.
24. `Can you turn off the kitchen light?` | `` — Can you turn off the kitchen light?
