# 精度改善 v6 — 助詞列と英語境界

2108a60を固定比較。モデル重み・辞書を変更せず、現在の未確定文だけから区間を判定する。Enterは文ごと。確定文や以前の言語ラベルを参照しない。

## 変更

- 4文字でローマ字にも読める既知英語を、明確な日本語境界で許可。単なる助詞らしい部分文字列では許可せず、「ものです」中のnodeの誤抽出を防ぐ。
- 大文字で始まる既知英語＋日本語の2区間を探索。従来の単一spanとjapaneseStartの表現を維持し、JSONdesuを扱う。
- 既知日本語＋助詞2個を境界根拠として評価し、ashita+made+niのniをcallbackに巻き込む誤りを減らす。
- 未知英語候補の同点付近だけ、上限つきの日本語確率ペナルティで選択。強い確率ペナルティは退行したので不採用。

評価例の単語追加はない。0.12や0.02などの値はこの開発評価に基づく規則であり、独立評価で最適と確認された値ではない。

## 既存比較

49テスト成功、既存96文96/96を維持。各セットで旧版正解→新版不正解ゼロ。

| セット | 区間一致 v5→v6 | 英語破損 | ラベル反転 |
|---|---:|---:|---:|
| prior80 | 80→80/80 | 50→50 | 173→173 |
| multi | 35→35/36 | 18→18 | 106→102 |
| prior24 | 23→23/24 | 6→6 | 79→75 |
| prior48 | 47→47/48 | 32→32 | 232→160 |
| priorfinal24 | 24→24/24 | 13→7 | 127→124 |
| development48 | 48→48/48 | 21→20 | 182→180 |
| final40 | 40→40/40 | 14→14 | 129→131 |
| v5追加48 | 41→45/48 | 74→59 | 166→171 |
| v6途中追加48 | 38→46/48 | 96→52 | 169→152 |

区間一致は全文字の日英ラベルで、漢字変換の正解率ではない。英語破損は完成済み英語の文字を日本語にしたprefixフレーム数。反転は前の文字ラベルが変わった打鍵数で、正しい修正も含む。一部セットでは反転が増加した。

途中追加48文は最初の評価後に既存40文の退行修正を行ったため、開発用へ移した。first-evaluation.sha256とfresh-result.jsonは修正前の履歴。最終結果はrecheck/developmentV6.json。

## 推論固定後の別の48文

final-evaluation.jsonを追加し、結果を見た後に推論変更なし。

- 区間一致: **25→27/48**
- 英語破損: **138→117**
- ラベル反転: **208→194**
- 旧版の完成文正解を失った例: **0**

既存課題セットより大幅に低い。日本語の名詞句が長い場合に英語へ巻き込む（kaigide+roadmap、gazouno+background等）、CSV/LF/UTCとdesuの境界、短語on/demo/mira、空白のないURLの終端が課題。失敗21文をfinal-failures.jsonに全件保持。URL終端は文字列だけでは意図が曖昧な課題も含む。一般的な文章で十分な精度に達したとは言えない。

いずれも自作の小規模診断で語彙重複あり。独立の実利用ベンチマークではない。異なるセットの正解率は直接比較しない。次回この48文から修正するときは開発用へ移す。

## 再現

```sh
./LocalModel/check-quality.sh
LOCAL_ACCURACY_BASELINE=2108a60 LOCAL_ACCURACY_CASES=LocalModel/accuracy-v6/final-evaluation.json LOCAL_ACCURACY_REPORT=/tmp/v6-final.json swift test --package-path Core --skip-build --filter localAccuracyComparison
```

check-accuracy-v6.pyは各文の退行とセットごとの英語破損増加を検出し、v5追加48文44以上・破損73以下等の目標を維持する。旧版の推論はテスト専用クラスに保存。

- [目標](accuracy-v6/GOAL.md)
- [推論・モデル・最終例文ハッシュ](accuracy-v6/frozen.sha256)
- [既存比較](accuracy-v6/recheck/summary.json)
- [固定後48文](accuracy-v6/final-evaluation.json) / [全結果](accuracy-v6/final-result.json) / [失敗](accuracy-v6/final-failures.json)
- [96文](accuracy-v6/regression-final.json)

## 実Zenzai・ビルド

Releaseビルド成功。署名済み独立bundleで67入力を実Zenzaiに通し、途中編集の復元・確定後消去に成功。APIキーなし、sandbox entitlementのみでネットワークentitlementなし。DNS失敗だけをオフライン証明とはしない。

実出力例:
- `sonoAPInoresponsehaJSONdesu` → そのAPIのresponseはJSONです
- `ashitamadenicallbacknotestwokakimasu` → 明日までにcallbackのtestを書きます
- `ima Notionnopagewohiraitemasu` → 今 Notionのpageを開いてます
- `konotoolchainnoconfigwoshirabemasu` → このtoolchainのconfigを調べます
- `konocachehaichijitekinamonodesu` → このcacheは一時的なものです

67文すべての漢字正解を保証する検査ではない。全出力はruntime-final.jsonに保存。初回文を除く打鍵時間p50 23.2ms、p95 67.7ms、最大494.7ms。冷起動の最大11.6秒は未解決。別評価と並行した1回の測定で、厳密な速度比較ではない。

[実出力](accuracy-v6/runtime-final.json) / [ビルド概要](accuracy-v6/build-summary.json)。署名済みローカルIMEとDemoアプリへ反映する。

## Web引き継ぎ

WASM版は別セッションが所有。実Zenzaiモデル単体のWeb生成は公開済みだが、Macの辞書候補選択と同等ではない。今回の区間判定変更を引き継ぎ、Swiftとの一致検証後に同じサイトを更新する。Web反映完了は別途の公開証拠で確認する。
