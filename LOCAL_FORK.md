# azooKey Local — stateless mixed-language prototype

azooKey-Desktop のローカル fork。Jev に頼っていた日英区間判定を、独自に学習した小型モデルで置き換えました。日本語のかな漢字変換には既存のローカル Zenzai を使用します。言語モード切替なしで、現在の未確定文から毎キー判定し、文末でまとめて確定できます。

## 実装

- 学習済み文字 1–4 gram / 単語 / 文脈特徴のロジスティック分類器と、英語＋日本語助詞の境界分類器。Swift のみで推論。
- 分類器 JSON は 150,605 bytes。これは追加分類器のサイズで、Zenzai の重みやアプリ全体のサイズではありません。
- TeX のコマンド・数式などは字句解析で保護。`\section{hajimeni}` の本文は `\section{はじめに}` に変換します。
- 判定に前の文や言語モードを引き継ぎません。未確定文・カーソル・描画キャッシュは保持します。Zenzai の個人学習は無効。
- インストールスクリプトはネットワーク entitlement を付与しません。API キー不要。旧 Jev クラスは回帰テスト用に残っていますが、通常の入力経路から呼びません。

## 起動

インストール済みの `~/Applications/azooKey Local Demo.app` を開きます。「デモを再生」で4例を実際のローカル変換経路で再生できます。通常のタイピングにも対応しています。

入力メソッド本体は `~/Library/Input Methods/azooKeyLocal.app` です。macOS の「キーボード → テキスト入力 → 編集」から入力ソースを追加してください。今回検証済みなのは共通セッションを使う専用エディタで、他アプリ上のシステム IME としての動作は未検証です。

## 再現

Xcode、Swift、Python 3、Git LFS が必要です。依存物の取得にはネット接続が必要ですが、変換時は不要です。

```sh
git submodule update --init --recursive
git -C azooKeyMac/Resources/gguf lfs pull
git -C azooKeyMac/Resources/base_n5_lm lfs pull
sh LocalModel/build.sh
python3 LocalModel/install.py .build-macos/Build/Products/Release/azooKeyMac.app
swift LocalModel/register-ime.swift
swift test --package-path Core --filter 'localModel|localLive|mixed|liveMixed|language|jev'
```

配布用 notarization は未実施です。install.py はデフォルトで ad-hoc 署名し、同名の Local 版だけを置換します。

学習を再現する場合：

```sh
python3 -m venv .venv
.venv/bin/pip install -r LocalModel/requirements.txt
.venv/bin/python LocalModel/train.py
```

`LocalModel/train.py` が学習データ・乱数 seed・特徴抽出を含みます。再学習後はアプリを再ビルドしてください。

## 検証結果と限界（2026-09-23）

39 テスト成功。Python と Swift の推論値を照合しました。分類器単体の短文平均は約 0.27ms（100回）。専用アプリで実際の Zenzai と結合し、各文字を入力して確認しました：

- `Google Meetの URL を Slack で 送ってもらえますか?`
- `Your session has expired と表示されて, ログインし直しても 先に進めません.`
- `返信は Thank you for your help でいいかな.もう少し丁寧にしたい.`
- `git pull したら conflict が 出たので, この PRの merge は 少し待ってください.`
- `数式は $E=mc^2$ です`
- `No problem, please send it to me` / `made in Japan` / `no errors` を英語のまま保持。

初回 Zenzai 読み込みを含むキー処理は最大約 11.4 秒。初回を除く後続3混在文の平均は 15.5–18.6ms/キー、最大約141ms。冷起動時に UI が待つため、本格利用には非同期初期化などの改善が必要です。

署名 entitlement から network.client/server を除去した状態で上記を実行。API キーファイルなし。別途 HTTPS 接続プローブも失敗しました（DNS エラー。エラーだけで sandbox が原因と断定するものではありません）。通常の変換処理は接続を行いません。

学習は手作成の語彙・合成例に基づきます。全文字列が学習データに混入しないよう除外した121語の正解率は95.0%、未見の途中入力は92.5%。自然文の実利用精度を示す数値ではありません。上記4デモも未知語評価ではありません。`no` / `to` などの短い曖昧入力は後続文脈により判定が変わり、表示が揺れることがあります。未知語・固有名詞・無空白混在文、TeX の全構文は未保証です。

モデル SHA256: `37a46dd8d91a1e8339730e9d08886f1a4d441ad8aef9bc0cdedaab8d9fe03b2c`

upstream の LICENSE を保持しています。これはローカル Git fork であり、GitHub への公開はしていません。
