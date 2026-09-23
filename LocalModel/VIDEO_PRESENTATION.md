# 動画用の区間判定表示

`azooKey Local Video.app` は録画専用の表示です。通常の入力メソッドとデモアプリの画面は変更しません。

- 上段：現在の実際の打鍵列。
- 中段：`session.lastDecision` の実際の区間。日本語をオレンジ、英語を水色、保護された記号をグレーで表示。
- 下段：実際の `session.buffer.display`。英語の原文と対応する区間を同色で示します。
- 確定は各文の最後に1回。確定後も直前の判定区間を残し、結果を比較できます。

判定・推論・変換は変更していません。入力途中の判定変更もそのまま表示します。完成時の判定を先に当てたり、出力を動画側で置換したりしません。表示用のビューは実際のセッションから値を読むだけです。

1200×675のコンテンツ領域を録画し、ウィンドウのタイトルバーを除いて1920×1080・30fpsで出力します。テロップや別の説明スライドは追加しません。

```sh
sh LocalModel/build.sh
python3 LocalModel/install-video.py .build-macos/Build/Products/Release/azooKeyMac.app
```

動画専用アプリは `~/Applications/azooKey Local Video.app`。「デモを再生」で4例を実演します。インストーラはこのアプリだけを更新し、ネットワーク entitlement を付けません。
