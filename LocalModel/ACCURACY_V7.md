# v7 — 補助スペースなしの日本語句・略語境界

比較元ab8bc42（推論ef66a1e）。モデル重み・英日語彙は変更せず、現在の未確定文だけから判定。日本語や日英の境界に補助スペースを要求しない。英語フレーズ内の空白は保持する。

## 改善

長い日本語句が辞書の短語より不利なため、kono|gazounobackground のように日本語を英語へ巻き込んでいた。未登録の6文字以上の日本語句で、末尾が既存助詞、助詞を除いてもローマ字として成立し、日本語確率が0.995以上の場合に短い既知語と同じ境界根拠を与える。句の内部または境界をまたいで4文字以上の既知英語単語が始まる場合は許可しない。既に既知語+1/2助詞で扱う境界は変更しない。ルールの根拠はこの開発評価であり、モデル確率が独立に較正済みという意味ではない。

2〜8文字の全大文字略語に続く4文字以上の日本語語尾を認識する。完全なローマ字・既存助詞で始まる・日本語確率0.95以上・既知英語語尾ではないことを条件にし、CSVdesu/LFdesu/UTCdesuのdesuを日本語へ戻す。USmade/HTMLParser/APInode/NASA/PDFdata等を英語のまま維持する回帰検査も追加。

未知語の日本語確率を強く罰するだけの変更や、長句すべてに根拠を与える変更は既存英語を壊すため不採用。診断案はdiagnosisに保存。評価例の語を辞書に足していない。

## 開発評価

v6の最終48文は今回の修正に使ったため、開発用へ移した。区間完全一致27→37/48、完成済み英語破損117→117フレーム、ラベル反転194→195。反転は1回増加しており、入力中の揺れ全般が減ったとはしない。

既存96文96/96維持、50テスト成功。区間一致は全文字の日英分類で、漢字変換の正解率ではない。英語破損は完成済み英語文字を日本語扱いした入力prefix数。反転には正しく修正されたラベルも含む。

固定後の別48文・全回帰比較・実Zenzai結果は後続節へ記録する。自作の小規模診断で、実利用の独立ベンチマークではない。

## Web

既存の独立セッションで、入力→区間→変換の一列のシンプルな画面に改修済み。直前結果は更新中と明記して薄く残し、最新結果になるまで確定不可。例文/履歴/詳細は折りたたむ。実Zenzai WASMとMac辞書探索の違いを詳細に保持する。ブラウザURL policy再拒否後は迂回せず、今回UIの目視QAは未実施。既存イベント/WASM制御・暫定表示テスト・HTTP配信一致は確認。

## 全回帰比較

10セットすべてで旧版の完成文正解から不正解への退行ゼロ、英語破損増加ゼロ。

| セット | 区間一致 旧→新 | 英語破損 | ラベル反転 |
|---|---:|---:|---:|
| prior80 | 80→80/80 | 50→50 | 173→173 |
| multi | 35→35/36 | 18→18 | 102→102 |
| prior24 | 23→23/24 | 6→6 | 75→75 |
| prior48 | 47→47/48 | 32→32 | 160→160 |
| priorfinal24 | 24→24/24 | 7→7 | 124→124 |
| development48 | 48→48/48 | 20→20 | 180→182 |
| final40 | 40→40/40 | 14→14 | 131→131 |
| fresh48 | 45→45/48 | 59→59 | 171→171 |
| developmentV6 | 46→46/48 | 52→52 | 152→152 |
| finalV6 | 27→37/48 | 117→117 | 194→195 |

略語修正でkonofolderniPDFwohozonshimasuの反転8→10も発生する。完成英語の破損は増えていないが、途中ラベルが全例で安定化したとは言わない。

## 実Zenzai・ローカル反映

Releaseビルド・署名検証成功。独立sandbox bundleで77入力を実行、途中編集の復元・確定後消去成功。APIキーなし・ネットワークentitlementなし。DNS失敗のみをオフライン証明にしない。署名済みIME/Demoへインストール済み。

実出力例:
- ashitanokaigideroadmapwokakuninshimasu → 明日の会議でroadmapを確認します
- konogazounobackgroundwoshirokushitaidesu → この画像のbackgroundを白くしたいです
- konosetteihadefaultnomamadesu → この設定はdefaultのままです
- konotablehaCSVdesu → このtableはCSVです

区間が正しくても漢字・読みまで正しいとは限らない。konohennocodewomisetekudasaiは「このへんおcodeを見せてください」で、期待した「この辺の」とは異なる。77例の全出力をruntime-final.jsonに保存し、この失敗も保持。

初回文を除く打鍵p50 29.5ms、p95 77.2ms、最大617.5ms。冷起動最大11.6秒は未解決。並行評価中の単発測定で、厳密な前版速度比較ではない。

## 推論固定後に別担当が作成した48文

別担当が推論や判定結果、語彙辞書を参照せず新規48文を作成。旧554種類とraw重複ゼロ。長い日本語句16・複数切替10・英語内部空白6・略語6・単言語6・保護構文4。ソース固定後、結果を見て推論を再調整していない。

- 区間完全一致 **29→31/48**
- 英語破損 **221→203フレーム**
- ラベル反転 **244→243**
- 旧版正解の完成文を失った例 **0**

失敗17件をfinal-failures.jsonに全件保存。既存課題の27→37ほど大きな改善は新規文に一般化していない。実利用で十分な精度に到達したとは言わない。作成者は問題の既知カテゴリを知っているため、判定結果からは独立でも問題全体から盲検されたコーパスではない。次に修正へ利用すれば開発用へ移す。

## 再現・証拠

`./LocalModel/check-quality.sh` で既存回帰とv7比較。個別の固定後評価は `LOCAL_ACCURACY_BASELINE=ab8bc42 LOCAL_ACCURACY_CASES=LocalModel/accuracy-v7/final-evaluation.json LOCAL_ACCURACY_REPORT=/tmp/v7-final.json swift test --package-path Core --skip-build --filter localAccuracyComparison`。

- [全回帰](accuracy-v7/recheck/summary.json)
- [固定後48文の全結果](accuracy-v7/final-result.json) / [失敗](accuracy-v7/final-failures.json)
- [例文の作成条件と限界](accuracy-v7/FINAL-FIXTURE-NOTES.md)
- [リリース固定ハッシュ](accuracy-v7/frozen.sha256)
- [実Zenzai77例](accuracy-v7/runtime-final.json) / [ビルド](accuracy-v7/build-summary.json) / [インストール](accuracy-v7/installation.json)

### 正解ラベルの訂正（原結果保持）

評価後のレビューでv7-final-031のsourceを日本語にした作問ミスが1件判明。作成担当が48文のraw/goldだけを再確認し、sourceの6文字だけ英語へ訂正した。raw変更・例文除外・推論変更はゼロ。元fixture/hash/全結果は保持。

同じ推論で訂正1件を旧版/新版とも再評価し、他47件の既存結果と結合した訂正版は **30→32/48、破損221→203、反転244→243**。改善幅は元結果と同じ+2件。訂正後失敗16件。final-corrected-result.json / final-corrected-summary.json / final-corrected-failures.json参照。check-accuracy-v7.pyは今後、訂正fixtureで32/48以上・破損203以下を維持する。原結果の31/48は訂正前の数値として残す。

FINAL-GOLD-REVIEW.md / final-gold-review.jsonに全件確認と理由を保存。明白な英語綴り混入は1件のみ。別文のkaemonoという誤字は日本語意図としてそのまま保持し、都合よく例文を除外していない。

## Web版v7公開

0aff807の推論差分をsimple UIへ移植し、38,793入力のSwift/Web構造比較で不一致0、確率差最大2.22e-15を確認。旧30,300入力を全保持し、新規48文の全prefix・全位置編集と略語の安全例を追加。区間移植の一致であり、Webモデル単体の漢字精度がMacと同じという意味ではない。

既存Cloudflare URLを更新、version 3a8b9c18-219e-4309-8b38-3b406779cf8b。シンプルな入力→区間→変換UI、WASMモデル、Enter/reset/取消制御を保持。新UI目視QAの安全審査ブロックは未解消。親セッションevidence/web-playground-session/RESULT-V7.mdおよびRESULT-SIMPLE-UI.mdが公開側記録。
