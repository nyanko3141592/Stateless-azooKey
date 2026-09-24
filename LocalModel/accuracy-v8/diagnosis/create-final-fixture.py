"""Gold-only fixture authoring. Does not import or execute any inference code."""
from pathlib import Path
import json
import hashlib
from collections import Counter

root=Path('work/azooKey-Local/LocalModel')
out=root/'accuracy-v8'
rows=[
('verb_modifier','朝予約したticketを確認します。',[('J','asayoyakushita'),('E','ticket'),('J','wokakuninshimasu')]),
('verb_modifier','友達から届いたinvitationを開いてください。',[('J','tomodachikaratodoita'),('E','invitation'),('J','wohiraitekudasai')]),
('verb_modifier','旅行前に作ったitineraryを家族に送りました。',[('J','ryokoumaenitsukutta'),('E','itinerary'),('J','wokazokuniokurimashita')]),
('verb_modifier','机に置いてあるadapterを持ってきてください。',[('J','tsukuenioitearu'),('E','adapter'),('J','womottekitekudasai')]),
('verb_modifier','午前中に直したlayoutが崩れています。',[('J','gozennchuuninaoshita'),('E','layout'),('J','gakuzureteimasu')]),
('verb_modifier','明日の会議で見せるprototypeを用意しました。',[('J','ashitanokaigidemiseru'),('E','prototype'),('J','woyouishimashita')]),
('verb_modifier','昨日更新したprofileに写真を追加したいです。',[('J','kinoukoushinshita'),('E','profile'),('J','nishashinwotsuikashitaidesu')]),
('verb_modifier','撮影の前に確認したexposureを少し下げます。',[('J','satsueinomaenikakuninshita'),('E','exposure'),('J','wosukoshisagemasu')]),
('verb_modifier','見たい映画をまとめたwatchlistを共有します。',[('J','mitaieigawomatometa'),('E','watchlist'),('J','wokyouyuushimasu')]),
('verb_modifier','引っ越したあとに変更したaddressが反映されません。',[('J','hikkoshitaatonihenkoushita'),('E','address'),('J','gahanneisaremasenn')]),
('verb_modifier','出張で使うvoucherを印刷しておきます。',[('J','shucchoudetsukau'),('E','voucher'),('J','woinsatsushiteokimasu')]),
('verb_modifier','皆で書いたretrospectiveを読み返しました。',[('J','minnadekaita'),('E','retrospective'),('J','woyomikaeshimashita')]),
('english_phrase','空港に着く前にboarding passを保存してください。',[('J','kuukounitsukumaeni'),('E','boarding pass'),('J','wohozonshitekudasai')]),
('english_phrase','今日の午後はmeeting roomを予約しています。',[('J','kyounogogoha'),('E','meeting room'),('J','woyoyakushiteimasu')]),
('english_phrase','説明を始める前にscreen sharingを有効にします。',[('J','setsumeiwohajimerumaeni'),('E','screen sharing'),('J','woyuukounishimasu')]),
('english_phrase','返金についてcustomer supportに相談しました。',[('J','henkinnnitsuite'),('E','customer support'),('J','nisoudanshimashita')]),
('english_phrase','新しい端末にもpassword managerを入れてください。',[('J','atarashiitanmatsunimo'),('E','password manager'),('J','woiretekudasai')]),
('english_phrase','仕事に集中したいときはfocus modeを使います。',[('J','shigotonishuuchuushitaitokiha'),('E','focus mode'),('J','wotsukaimasu')]),
('english_phrase','送る前にfile nameを分かりやすくしてください。',[('J','okurumaeni'),('E','file name'),('J','wowakariyasukushitekudasai')]),
('english_phrase','この動画のbackground musicの音量を少し下げます。',[('J','konodougano'),('E','background music'),('J','noonryouwosukoshisagemasu')]),
('english_phrase','先ほど届いたvoice messageをもう一度聞きたいです。',[('J','sakihodotodoita'),('E','voice message'),('J','womouichidokikitaidesu')]),
('english_phrase','共有する前にsearch historyを消しておきます。',[('J','kyouyuusurumaeni'),('E','search history'),('J','wokeshiteokimasu')]),
('english_phrase','帰りに買うものをshopping listに追加しました。',[('J','kaerinikaumonowo'),('E','shopping list'),('J','nitsuikashimashita')]),
('english_phrase','気になった記事をreading listに入れています。',[('J','kininattakijiwo'),('E','reading list'),('J','niireteimasu')]),
('multiple_switches','Chromeのtabを閉じてからSafariで開き直しました。',[('E','Chrome'),('J','no'),('E','tab'),('J','wotojitekara'),('E','Safari'),('J','dehirakinaoshimashita')]),
('multiple_switches','このformのemail欄にaddressを入力してください。',[('J','kono'),('E','form'),('J','no'),('E','email'),('J','ranni'),('E','address'),('J','wonyuuryokushitekudasai')]),
('multiple_switches','音声をrecordしてからnoiseを減らします。',[('J','onseiwo'),('E','record'),('J','shitekara'),('E','noise'),('J','woherashimasu')]),
('multiple_switches','このfolderのarchiveをcloudに移しました。',[('J','kono'),('E','folder'),('J','no'),('E','archive'),('J','wo'),('E','cloud'),('J','niutsushimashita')]),
('multiple_switches','昨日のmeetingのsummaryをSlackに送りました。',[('J','kinouno'),('E','meeting'),('J','no'),('E','summary'),('J','wo'),('E','Slack'),('J','niokurimashita')]),
('multiple_switches','このbuttonをclickするとdialogが開きます。',[('J','kono'),('E','button'),('J','wo'),('E','click'),('J','suruto'),('E','dialog'),('J','gahirakimasu')]),
('multiple_switches','次のslideのtitleとsubtitleを入れ替えます。',[('J','tsugino'),('E','slide'),('J','no'),('E','title'),('J','to'),('E','subtitle'),('J','woirekaemasu')]),
('multiple_switches','このcameraのbatteryとstorageを確認してください。',[('J','kono'),('E','camera'),('J','no'),('E','battery'),('J','to'),('E','storage'),('J','wokakuninshitekudasai')]),
('multiple_switches','購入したitemのtrackingをappで確認しました。',[('J','kounyuushita'),('E','item'),('J','no'),('E','tracking'),('J','wo'),('E','app'),('J','dekakuninshimashita')]),
('multiple_switches','あのplaylistをdownloadしてofflineで聴きたいです。',[('J','ano'),('E','playlist'),('J','wo'),('E','download'),('J','shite'),('E','offline'),('J','dekikitaidesu')]),
('multiple_switches','このdocumentのcommentにreplyを追加しました。',[('J','kono'),('E','document'),('J','no'),('E','comment'),('J','ni'),('E','reply'),('J','wotsuikashimashita')]),
('multiple_switches','画像をresizeしてからattachmentとして送り直します。',[('J','gazouwo'),('E','resize'),('J','shitekara'),('E','attachment'),('J','toshiteokurinaoshimasu')]),
('single_language','昼休みに近くの公園を散歩します。',[('J','hiruyasuminichikakunokouenwosanposhimasu')]),
('single_language','次の電車が来るまでここで待ちます。',[('J','tsuginodenshagakurumadekokodemachimasu')]),
('single_language','冷蔵庫に残っている野菜で夕飯を作ります。',[('J','reizoukoninokotteiruyasaideyuuhanwotsukurimasu')]),
('single_language','Could you leave the package by the front door?',[('E','Could you leave the package by the front door?')]),
('single_language','The meeting starts after lunch, so we still have time.',[('E','The meeting starts after lunch, so we still have time.')]),
('single_language','I saved a copy before making any changes.',[('E','I saved a copy before making any changes.')]),
('protected_syntax','距離は\\sqrt{x^2+y^2}で表せます。',[('J','kyoriha'),('E',r'\sqrt{x^2+y^2}'),('J','dearawasemasu')]),
('protected_syntax','この判定では$p < 0.05$を目安にします。',[('J','konohanteideha'),('E','$p < 0.05$'),('J','womeyasunishimasu')]),
('protected_syntax','状態は`git status --short`で確認してください。',[('J','joutaiha'),('E','`git status --short`'),('J','dekakuninshitekudasai')]),
('protected_syntax','この項目の名前を`theme_color`に変えました。',[('J','konokoumokunonamaewo'),('E','`theme_color`'),('J','nikaemashita')]),
('protected_syntax','接続先はhttps://api.example.org/v1/items',[('J','setsuzokusakiha'),('E','https://api.example.org/v1/items')]),
('protected_syntax','申込方法はこちらhttps://example.net/events/signup',[('J','moushikomihouhouhakochira'),('E','https://example.net/events/signup')]),
]
expected={'verb_modifier':12,'english_phrase':12,'multiple_switches':12,'single_language':6,'protected_syntax':6}
assert dict(Counter(category for category,_,_ in rows))==expected
old=set()
def collect(v):
    if isinstance(v,dict):
        if isinstance(v.get('raw'),str):old.add(v['raw'])
        for item in v.values():collect(item)
    elif isinstance(v,list):
        for item in v:collect(item)
for p in root.rglob('*.json'):
    if 'accuracy-v8' in p.parts:continue
    try:collect(json.loads(p.read_text()))
    except (ValueError,UnicodeError):pass
cases=[];review=[]
for i,(category,intent,segments) in enumerate(rows,1):
    raw=''.join(s for _,s in segments)
    assert raw.isascii(),raw
    assert raw not in old,raw
    assert raw not in {c['raw'] for c in cases},raw
    jp=[];en=[];offset=0
    for language,text in segments:
        assert text
        if language=='J':
            assert text.isalpha() and text.islower(),text
            jp.append([offset,offset+len(text)])
        else:
            assert language=='E'
            en.append([offset,offset+len(text)])
        offset+=len(text)
    assert all(0<=a<b<=len(raw) for a,b in jp+en)
    assert not any(max(a,c)<min(b,d) for a,b in jp for c,d in en)
    assert all(any(a<=i<b for a,b in en) for i,c in enumerate(raw) if c.isspace())
    assert sum(b-a for a,b in jp+en)==len(raw)
    case=dict(id=f'v8-final-{i:03}',raw=raw,japaneseRanges=jp,englishRanges=en)
    cases.append(case)
    review.append(dict(id=case['id'],category=category,intendedText=intent,japanese=[s for l,s in segments if l=='J'],english=[s for l,s in segments if l=='E']))
assert len(cases)==48
path=out/'final-evaluation.json'
path.write_text(json.dumps(cases,ensure_ascii=False,indent=2)+'\n')
(out/'diagnosis'/'final-authored-segments.json').write_text(json.dumps(review,ensure_ascii=False,indent=2)+'\n')
print(json.dumps(dict(count=len(cases),categoryCounts=expected,oldDistinctRawsChecked=len(old),sha256=hashlib.sha256(path.read_bytes()).hexdigest()),indent=2))
for x in review:print(x['id'],x['intendedText'],'J=',x['japanese'],'E=',x['english'])
