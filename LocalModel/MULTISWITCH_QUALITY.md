# 空白なしの日英複数切替 — 実装・評価記録

1つの空白なし入力を「英語の接頭部＋日本語」の1境界に限定していた処理を、複数の交互区間を選ぶ処理へ拡張しました。学習済みモデルの重みは変えていません。モデルの判定・語彙・ローマ字の音節条件から区間を選ぶ処理と、その区間を使う表示処理の変更です。

## 実装

- 動的計画法で英語／日本語が交互に現れる候補を比較。入力の文字列をそのまま切り分け、文字は生成しません。
- 既知の英単語、確信度の高い未知語候補、入力途中の英単語候補を扱います。日本語として読める全文字列や既知の英語連結語には保守的な制約を付けています。
- 表示処理は、現在の未確定入力と完全に一致する区間分けだけを利用。古い入力の区間分けは採用しません。
- 文中のカーソル移動、挿入→削除、文末確定を確認。言語モードや前の文は参照していません。

## 正解率と安定性は別に測定

| 指標 | 旧版 c177cb1 | 今回 |
|---|---:|---:|
| 既存96例の最終日英区間完全一致 | 95/96 | 96/96 |
| 追加36例の最終日英区間完全一致 | 17/36 | 27/36 |
| 追加36例で既入力部分の日英ラベルが反転した打鍵回数 | 57 | 106 |
| 入力済み英単語のどこかを日本語扱いした途中入力数 | 165/771 | 166/771 |

**複数切替の最終判定は改善しましたが、途中入力の安定性は改善できていません。** 反転数には後続文脈で正しい判定へ直る変更も含まれ、見た目のちらつきそのものの回数ではありません。漢字候補の変化も数えていません。この指標の悪化を隠して「ライブ変換が安定した」とはしていません。

追加例は自作です。最初の24例は実装を固定して一度測定（11/24→17/24、反転38→88）し、その後、仮入力の処理を一般的に修正しました。さらに12例を追加して測定（6/12→9/12）。結果確認後に、最初の24例に含まれる英語連結語の保護を追加しています。最終12例の成績はその前後で変わっていません。全36例を厳密な未使用テスト集合とは呼びません。既知語彙の重複があり、外部の独立ベンチマークでもありません。

## 実アプリでの出力

- `Slacknoscreenshotwookuttekudasai.`
  - Slackのscreenshotを送ってください.
- `GitHubnobranchwokaetekudasai.`
  - GitHubのbranchを変えてください.
- `ashitanomeetingnolinkwooshietekudasai.`
  - 明日のmeetingのlinkを教えてください.
- `konofilewoSlackdekyouyuushitekudasai.`
  - このfileをSlackで共有してください.

以上4例を実際のローカルセッションへ1文字ずつ入力し、文ごとに確定する実演を録画。結果の差し替えはありません。録画は16:9へトリミングするだけです。

## 残存する失敗（追加例は修正・除外していません）

- `raishuunomeetingnoagendawooshietekudasai`
- `Chromenobookmarkgasyncsaremasenn`
- `konothumbnailwodownloadshitaidesu`
- `shinkinopullrequestworeviewshitekudasai`
- `konodatasetnoschemawokakuninnshimasu`
- `atesakihateam+review@example.comdesu`
- `atarashiifeaturenotestwotsuikashimasu`
- `konodashboardnowidgetwokesitai`
- `saishinnochangelogwobrowserdehiraku`

未知語の位置を正しく切れず、`pullrequest` の一部を日本語にしたり、`dataset` を途中で分けたりする場合があります。メールアドレスに区切りなしで続く `desu` も、アドレスの一部として保持されます。これらは今後の課題です。

## 検証と速度

- 48テスト成功、Releaseビルド成功。
- 実アプリ40例をローカルZenzaiと合わせて実行。APIキーファイルなし。ネットワーク entitlement なし。
- 文中の挿入→削除後に元の変換へ戻ること、確定後の未確定文・判定・タスク消去を確認。
- macOSの他アプリ上での入力メソッド動作は未検証。専用エディタと同じセッション実装の検証です。
- 分類・区間分け単体（同じ36例の全途中入力、Swiftテスト）：before 平均 0.23ms、p95 0.50ms。テストは他のテストと並行するため実機の入力遅延全体とは異なります。
- 分類・区間分け単体（同じ36例の全途中入力、Swiftテスト）：after 平均 1.37ms、p95 5.87ms。テストは他のテストと並行するため実機の入力遅延全体とは異なります。
- Zenzaiを含む実アプリ40例のキー処理（最初の例を除外）：平均 17.5ms、p95 52.3ms、最大 865.3ms。遅い更新が残っており、常に低遅延とは言えません。

## 再現

```sh
LOCAL_MULTI_REPORT=/tmp/multi.json LOCAL_QUALITY_REPORT=/tmp/regression.json swift test --package-path Core --filter 'localMulti|localQuality|localModel|localLive|mixed|liveMixed|language|jev'
```

旧版の分類器はテストターゲットだけに保存し、同じモデルと同じ入力で比較しています。アプリには含みません。

- [追加36例と期待区間](multiswitch-evaluation.json)
- [旧版・新版の全判定と途中入力計測](multiswitch-quality/routing.json)
- [既存96例の回帰結果](multiswitch-quality/regression.json)
- [実アプリ40例の全出力](multiswitch-quality/runtime.json)
- [初回24例の固定時点の結果](multiswitch-quality/initial-frozen-24.json)
- [出荷する推論ソースのハッシュ](multiswitch-quality/shipping-source.sha256)
