# Stateless-azooKey

日英モードを切り替えず、現在の未確定入力から区間を判定するmacOS向けの実験的IMEです。軽量分類器＋辞書・ルールで日英を分け、日本語区間をZenzaiで変換します。

> [!IMPORTANT]
> これは高橋直樹が保守する**非公式フォーク**です。azooKey開発者・azooKeyプロジェクト・Zenzai作者による公式リリースではなく、承認や推奨を受けたものでもありません。フォーク固有部分の不具合・誤変換・問い合わせを上流へ送らないでください。

このフォークは、三輪敬太氏およびコントリビューターによる[azooKey on macOS](https://github.com/azooKey/azooKey-Desktop)を基盤とし、同氏のニューラルかな漢字変換モデルZenzaiとAzooKeyKanaKanjiConverterを利用しています。本フォークが独自に追加したのは、ローカル日英区間推定、ステートレス入力経路、評価・デモ周辺です。詳細は[FORK_NOTICE.md](FORK_NOTICE.md)と[LICENSE](LICENSE)を参照してください。

[最新の精度改善と評価](LocalModel/ACCURACY_V3.md) / [公開準備・既知の問題](LocalModel/RELEASE_READINESS.md) / [評価の再現](LocalModel/check-quality.sh) / [動画用表示](LocalModel/VIDEO_PRESENTATION.md)

本プロジェクトはバイナリやインストーラを配布しません。各自のMac上でソースからビルドしてください。ビルドは `sh LocalModel/build.sh`、別名インストールは `python3 LocalModel/install.py .build-macos/Build/Products/Release/azooKeyMac.app` です。

## azooKey on macOS

[azooKey](https://github.com/ensan-hcl/azooKey)のmacOS版です。高精度なニューラルかな漢字変換エンジン「Zenzai」を導入した、オープンソースの日本語入力システムです。

**現在アルファ版のため、動作は一切保証できません**。

## 動作環境

macOS 15で動作確認しています。macOS 14およびmacOS 26でも利用できますが、動作は検証していません。

# 自分でビルドして使う

```bash
git lfs install
git clone --recursive https://github.com/nyanko3141592/Stateless-azooKey.git
cd Stateless-azooKey
git -C azooKeyMac/Resources/gguf lfs pull
git -C azooKeyMac/Resources/base_n5_lm lfs pull
sh LocalModel/build.sh
python3 LocalModel/install.py .build-macos/Build/Products/Release/azooKeyMac.app
```

インストール後に一度ログアウトして再ログインし、「システム設定」→「キーボード」→「入力ソース」→「編集」→「＋」→「日本語」から `Stateless-azooKey` を追加します。既存の公式azooKeyとは別のBundle ID・入力ソースIDで共存します。

更新時は同じ手順で再ビルド・再インストールし、必要に応じて `Stateless-azooKey` のプロセス終了または再ログインを行ってください。

## コミュニティ

azooKey on macOSの開発に参加したい方、使い方に質問がある方、要望や不具合報告がある方は、ぜひ[azooKeyのDiscordサーバ](https://discord.gg/dY9gHuyZN5)にご参加ください。


### azooKey on macOSを支援する

GitHub Sponsorsをご利用ください。


## 機能

* ニューラルかな漢字変換システム「Zenzai」による高精度な変換
  * プロフィールプロンプト機能
  * 履歴学習機能
  * ユーザ辞書機能
  * 個人最適化システム「[Tuner](https://github.com/azooKey/Tuner)」との連携機能
* LLMによる「いい感じ変換」機能
* ライブ変換
* AZIKのネイティブサポート


## 開発ガイド

コントリビュート歓迎です！！

### 必要な環境
* macOS 15+
* Xcode 26.1+
* Git LFS（必須。Hugging Face上のsubmoduleがLFSを利用しているため、未導入だとモデル重みが取得できません）
* SwiftLint

```bash
brew install git-lfs swiftlint
git lfs install
```

### 開発版のビルド・デバッグ

#### 1. クローン

submoduleにzenzのgguf重みと言語モデル（`.marisa`）が含まれるため、`--recursive`と Git LFS の有効化が必須です。

```bash
git lfs install        # 未実行の場合のみ
git clone https://github.com/nyanko3141592/Stateless-azooKey --recursive
cd Stateless-azooKey
```

既にcloneしていてsubmoduleやLFSが揃っていない場合は以下を実行してください。

```bash
git submodule update --init
git -C azooKeyMac/Resources/gguf lfs pull
git -C azooKeyMac/Resources/base_n5_lm lfs pull
```

重みファイルが正しく取得できているか、サイズで確認できます（数十MB以上あればLFSの実体、134B程度ならポインタのままです）。

```bash
ls -lh azooKeyMac/Resources/gguf/ggml-model-Q5_K_M.gguf
```

#### 2. ビルド＆インストール

```bash
sh LocalModel/build.sh
python3 LocalModel/install.py .build-macos/Build/Products/Release/azooKeyMac.app
```

この開発用手順はローカルでad-hoc署名し、`~/Library/Input Methods/Stateless-azooKey.app` へインストールします。第三者へ渡せる署名済みバイナリは生成しません。その後、ログアウト→再ログイン→入力ソース追加を行ってください。

開発中はazooKeyのプロセスをkillすることで最新版を反映することが出来ます。また、必要に応じて入力ソースからazooKeyを削除して再度追加する、macOSからログアウトして再ログインするなど、リセットが必要になる場合があります。

### 開発時のトラブルシューティング

`LocalModel/build.sh`でビルドが成功しない場合、以下をご確認ください。

* 「Packages are not supported when using legacy build locations, but the current project has them enabled.」と表示される場合は[https://qiita.com/glassmonkey/items/3e8203900b516878ff2c](https://qiita.com/glassmonkey/items/3e8203900b516878ff2c)を参考に、Xcodeの設定をご確認ください
* Xcode 26.0ではビルドできない可能性があります。Xcode 16系または26.1以降をご利用ください。

変換精度がリリース版に比べて悪いと感じた場合、以下をご確認ください。
* Git LFSが導入されていない環境では、重みファイルがローカル環境に落とせていない場合があります。`azooKeyMac/Resources/gguf/ggml-model-Q5_K_M.gguf` が数十MB以上あるかを確認し、ポインタのままであれば `git -C azooKeyMac/Resources/gguf lfs pull` を実行してください

## Community Forks

### [fcitx5-hazkey](https://github.com/7ka-Hiira/fcitx5-hazkey)
@7ka-Hiira さんによるLinux系OS向けのクライアント実装です。

### [azooKey-Windows](https://github.com/fkunn1326/azooKey-Windows)
@fkunn1326 さんによるWindows向けクライアント実装です。

### [azoo-key-skkserv](https://github.com/gitusp/azoo-key-skkserv)
@gitusp さんによるSKKクライアント向けのSKKサーバ実装です。macOS向けGUIアプリケーションを含みます。

## Reference

Thanks to authors!!

* https://mzp.hatenablog.com/entry/2017/09/17/220320
* https://www.logcg.com/en/archives/2078.html
* https://stackoverflow.com/questions/27813151/how-to-develop-a-simple-input-method-for-mac-os-x-in-swift
* https://mzp.booth.pm/items/809262

## Acknowledgement
本プロジェクトは情報処理推進機構(IPA)による[2024年度未踏IT人材発掘・育成事業](https://www.ipa.go.jp/jinzai/mitou/it/2024/koubokekka.html)の支援を受けて開発を行いました。
