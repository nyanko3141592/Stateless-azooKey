# v9 — 英語で始まる未確定文

推論source63639ee、比較元055b8a4。classify内のenglishPhrase条件にspans.isEmptyを追加するだけ。元々英語+空白の後に許していた、既知英語と強い日本語tailの境界を入力の最初のspanにも認める。助詞/動詞接頭辞、4文字以上、日本語らしさ0.88、完全/途中ローマ字等の条件は保持。日本語後の空白には適用を広げない。モデル語彙・重み・MixedSegmenterは不変。現在の未確定文だけを参照し、確定履歴なし。

## 開発と評価の分離

開発28例は完成23→24、完成英語破損58→21prefix、反転124→82。純英語・曖昧安全18例は18/18、破損0、反転3で不変。単に全位置で条件を緩める案は、日本語の後のmeetingの入力途中破損0→2で棄却。未知英語拡張は採用しなかった。

既存636例中、影響し得る先頭既知英語72例をJSで全prefix実測しexact/damage/reversal不変。他564例は変更経路への到達条件を満たさない。全636例を今回全prefix実測したとは言わない。既存96例の一部fixtureにはenglishRangesがなく、そのセットのdamageは未評価。詳細はaccuracy-v9/RECOMMENDATION.md。

推論を固定してから別担当が予測・語彙・推論ソースを見ずに24文を作成し、goldを二度点検。JS比較は完成15→16/24、英語破損158→146、反転185→156。旧正解退行なし。calendar/backupの入力途中安定化、headphoneの完成境界が改善。8例失敗は残る。結果を見て推論・goldを変更していない。モデルに未知の語かは語彙未閲覧のため保証しない。

数値は自作小標本の区間一致で、漢字変換の正解率や実利用全体の精度ではない。反転には正しい修正も含む。fresh24は今後調整に使った時点で開発用とし、未見評価と再称しない。

## Swift確認

92テスト成功、既存96文96/96。Swiftの開発46文（英語先頭28+安全18）41→42正解、破損58→21、反転127→85。独立24文15→16、破損158→146、反転185→156でJSと一致。影響範囲72文は71/72、破損0、反転37で全不変。全比較で個別の旧正解退行なし。source hashも固定時と一致。

再現: `swift test --package-path Core -j 2` の後、`python3 LocalModel/accuracy-v9/run-comparisons.py`。元fixtureの再生成なし。prior72の一部はenglishRangesが無いためdamage0を全英語安全の証拠とはしない。exactと反転は全72で比較。

今回はWeb向け区間改善と説明/公開ソース整備。MacのRelease再ビルド・アプリ再インストール・実Zenzai再監査はこの版では実施していない。既存インストール版はv8。Web新版も実ブラウザURL制約のためCLI/HTTP検証とし、実ブラウザ操作確認とは呼ばない。

## Web公開

source63639eeを移植し54,687入力（既存47,359を保持、新46+24文のprefix/編集追加）でSwift/Webの区間構造不一致0。確率最大差1.9984e-15。既存queue/load/interaction/区間worker復帰テストも維持。Cloudflare version ae1836f6-2242-4e25-86b8-f813d0481bec。サイトcommit a85bf535d74f21d61ddaeee885acce18bffe38c0。7配布ファイルをHTTP取得してbyte一致、公開source.zip内routerも一致。

URL: https://azookey-local-playground-20260923.takahashinaoki521.workers.dev

about.htmlで仕組み・通信/保存・制約・Macとの差・ライセンスを説明。source.zipはWeb再現用コード・小モデル・読み表・必要なライセンスと第三者資産取得手順を含む。学習/Swift/アプリの完全な公開アーカイブとは主張しない。秘密・内部ログ・個人絶対パスはallowlist方式で除外。主要Web変更と自作区間モデルはMIT、Zenz GGUFは公式モデルカードのApache-2.0、wllama/llama.cpp等は個別の全文を保持。配布物の監査であり、権利全般の保証・法的助言ではない。

ライセンス監査と公開用ソースについては別WebセッションのRESULT-OPEN.md、dist/license-audit.json、dist/source-manifest.jsonを参照。一般向けの変更は入力画面の小リンクと別説明ページに分離した。

独立24文で残った全8失敗はaccuracy-v9/RESIDUAL_ERRORS.mdにgold/実区間を併記。screen sharing、meeting room、Google Maps、CPU fan、paperless、microblog、Readwise、deskmatを含む文が未解決。
