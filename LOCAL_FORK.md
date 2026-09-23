# azooKey Local — stateless mixed-language prototype

azooKey-Desktop のローカル fork。Jev に頼っていた日英区間判定を、独自に学習した小型モデルで置き換えました。日本語のかな漢字変換には既存のローカル Zenzai を使用します。言語モード切替なしで、現在の未確定文から毎キー判定し、文末でまとめて確定できます。

最新の複数切替対応版は [追加実装・品質記録](LocalModel/MULTISWITCH_QUALITY.md) を参照してください。空白なしの複数切替の判定範囲は広がりましたが、途中表示の安定性と遅延は引き続き課題です。

## 実装

- 学習済み文字 1–4 gram / 単語 / 文脈特徴のロジスティック分類器と、英語＋日本語助詞の境界分類器。Swift のみで推論。
- 分類器 JSON は 473,661 bytes。これは追加分類器のサイズで、Zenzai の重みやアプリ全体のサイズではありません。
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

44 テスト成功。Python と Swift の推論値を照合しました。分類器単体の短文平均は約 0.48ms（100回）。専用アプリで実際の Zenzai と結合し、各文字を入力して確認しました：

- `Google Meetの URL を Slack で 送ってもらえますか?`
- `Your session has expired と表示されて, ログインし直しても 先に進めません.`
- `返信は Thank you for your help でいいかな.もう少し丁寧にしたい.`
- `git pull したら conflict が 出たので, この PRの merge は 少し待ってください.`
- `数式は $E=mc^2$ です`
- `No problem, please send it to me` / `made in Japan` / `no errors` を英語のまま保持。

初回 Zenzai 読み込みを含むキー処理は最大約 11.4 秒。初回を除く後続3混在文の平均は 15.5–18.6ms/キー、最大約141ms。冷起動時に UI が待つため、本格利用には非同期初期化などの改善が必要です。

署名 entitlement から network.client/server を除去した状態で上記を実行。API キーファイルなし。別途 HTTPS 接続プローブも失敗しました（DNS エラー。エラーだけで sandbox が原因と断定するものではありません）。通常の変換処理は接続を行いません。

学習は手作成の語彙・合成例に基づきます。現行版は分類器に加えて英語／日本語の語彙表、文脈ルール、字句解析を使うハイブリッド方式です。小型分類器だけで全てを判断するものではありません。

固定48文の日英区間完全一致は初版37/48 → 改善版48/48。全96例の回帰例では95/96。評価例の失敗を実装改善に使用しており、自然文に対する汎化精度を保証する数値ではありません。漢字選択の正解率でもありません。詳細・残存失敗・実アプリ出力は [品質レポート](LocalModel/QUALITY.md) を参照してください。

学習コードの263語の単語ホールドアウト評価は、分類器単体の確率に対するものです。製品の語彙表にはそれらの英単語も含むため、製品の未知語精度とは呼びません。未知語・空白なしの複数回の日英切替、短い曖昧入力には失敗が残ります。

モデル SHA256: `e39825afc0a3badfc6e613d05fa600b7d0d0267816e46c45835e916f0dc9a69d`

upstream の LICENSE を保持しています。これはローカル Git fork であり、GitHub への公開はしていません。
