"""Author fixed gold spans without executing any language router or reading its lexicon."""
import hashlib
import json
from collections import Counter
from datetime import datetime, timezone
from pathlib import Path

root = Path('work/azooKey-Local/LocalModel')
out = root / 'accuracy-v7'
# J: intended Japanese romaji; E: literal English or protected syntax; P: punctuation/space.
rows = [
('long_japanese_phrase', [('J','senshuunouchiawasedekimeta'),('E','deadline'),('J','wokakuninshitaidesu')]),
('long_japanese_phrase', [('J','gamennomigishitaniaru'),('E','checkbox'),('J','wohazushitekudasai')]),
('long_japanese_phrase', [('J','yomikakenokijino'),('E','bookmark'),('J','woseirishimashita')]),
('long_japanese_phrase', [('J','kinoukarashirabeteiru'),('E','regression'),('J','noriyuugawakarimashita')]),
('long_japanese_phrase', [('J','kaiginomaeniokutta'),('E','attachment'),('J','gahirakemasenn')]),
('long_japanese_phrase', [('J','shuunohajimenitsukutta'),('E','checklist'),('J','wominaoshimashou')]),
('long_japanese_phrase', [('J','konoshashinnohaikeiniaru'),('E','watermark'),('J','gakininarimasu')]),
('long_japanese_phrase', [('J','minnadehanashiattekimeta'),('E','milestone'),('J','wokaemashita')]),
('long_japanese_phrase', [('J','shoriganagabikutokino'),('E','timeout'),('J','wonobashitaidesu')]),
('long_japanese_phrase', [('J','atarashiipasokonnniutsushita'),('E','workspace'),('J','gamitsukarimasenn')]),
('long_japanese_phrase', [('J','hozonshitaonseinosaishono'),('E','timestamp'),('J','wooshietekudasai')]),
('long_japanese_phrase', [('J','kaerumaenikakuninshita'),('E','invoice'),('J','nikingakugahaitteimasenn')]),
('long_japanese_phrase', [('J','saigonominaoshidekizuita'),('E','typo'),('J','wonaoshimashita')]),
('long_japanese_phrase', [('J','tsuginojikkennitsukau'),('E','dataset'),('J','woyouishimasu')]),
('long_japanese_phrase', [('J','hitotsumaenogamennimodoru'),('E','shortcut'),('J','wooboetaidesu')]),
('long_japanese_phrase', [('J','konohonndetokinikiniitta'),('E','chapter'),('J','woyomikaeshiteimasu')]),
('multiple_switches', [('J','kinouno'),('E','Zoom'),('J','no'),('E','recording'),('J','wo'),('E','Drive'),('J','nihozonshita')]),
('multiple_switches', [('J','konoshashinwo'),('E','crop'),('J','shitekara'),('E','thumbnail'),('J','nishimasu')]),
('multiple_switches', [('J','asaichide'),('E','inbox'),('J','wokakuninshite'),('E','newsletter'),('J','woyomimashita')]),
('multiple_switches', [('J','sonokijiwo'),('E','bookmark'),('J','shite'),('E','tag'),('J','wotsuketekudasai')]),
('multiple_switches', [('J','atarashii'),('E','branch'),('J','de'),('E','hotfix'),('J','wo'),('E','commit'),('J','shimashita')]),
('multiple_switches', [('J','sakkino'),('E','animation'),('J','no'),('E','duration'),('J','wosukoshinagakushita')]),
('multiple_switches', [('J','konotsuuchiha'),('E','mobile'),('J','dake'),('E','mute'),('J','nishitaidesu')]),
('multiple_switches', [('J','konogamenno'),('E','header'),('J','to'),('E','footer'),('J','de'),('E','font'),('J','gachigaimasu')]),
('multiple_switches', [('J','kesaokutta'),('E','proposal'),('J','no'),('E','feedback'),('J','womoraemashitaka')]),
('multiple_switches', [('J','konotsuushinha'),('E','retry'),('J','shitemo'),('E','status'),('J','gakawarimasenn')]),
('english_phrase', [('J','koukaimaeni'),('E','release notes'),('J','woyominaoshimashou')]),
('english_phrase', [('J','shuumatsumadeni'),('E','pull request'),('J','womatometekudasai')]),
('english_phrase', [('J','yorumadetsukautokidake'),('E','dark mode'),('J','nikirikaetaidesu')]),
('english_phrase', [('J','shippaishitatokino'),('E','error message'),('J','wosonomamaokuttekudasai')]),
('english_phrase', [('J','kaishanosourcenohozonbashoha'),('E','private repository'),('J','desu')]),
('english_phrase', [('J','gamenzentainotouitsukannwodasutameni'),('E','design system'),('J','wotsukurimasu')]),
('uppercase_acronym', [('J','konoinsatsuyounoshiryouha'),('E','PDF'),('J','deokuttekudasai')]),
('uppercase_acronym', [('J','kakidashitasetteinohoushikiha'),('E','YAML'),('J','desu')]),
('uppercase_acronym', [('J','konokeisannwo'),('E','GPU'),('J','dehayakushitaidesu')]),
('uppercase_acronym', [('J','shorinishiyoushita'),('E','CPU'),('J','nojikannwokeisokushita')]),
('uppercase_acronym', [('J','konotsuushinohoushikiha'),('E','HTTPS'),('J','nishitekudasai')]),
('uppercase_acronym', [('J','jitakunodougasouchino'),('E','HDMI'),('J','gasasatteimasenn')]),
('single_language', [('J','ashitahayakuokirunodekyouhamouyasumimasu')]),
('single_language', [('J','shigotonokaeriniekinomaedekaemonowoshimasu')]),
('single_language', [('J','maeniyondahonnonamaegadoushitemoomoidasemasenn')]),
('single_language', [('E','Please send the original image before tomorrow.')]),
('single_language', [('E','We need more time to review the proposed changes.')]),
('single_language', [('E','The download finished but the file is still missing.')]),
('protected_syntax', [('J','futatsunoatainoheikinwo'),('E',r'\frac{x+y}{2}'),('J','dearawashimasu')]),
('protected_syntax', [('J','konoshikinojoukenha'),('E','$x>0$'),('J','desu')]),
('protected_syntax', [('J','tsuikashitasetteiha'),('E','`cache_max_age`'),('J','desu')]),
('protected_syntax', [('J','tsuzukiha'),('E','https://example.org/guide/setup')]),
]

expected = {'long_japanese_phrase':16,'multiple_switches':10,'english_phrase':6,'uppercase_acronym':6,'single_language':6,'protected_syntax':4}
assert dict(Counter(category for category,_ in rows)) == expected
old_raws=set()
def collect(value):
    if isinstance(value,dict):
        if isinstance(value.get('raw'),str):old_raws.add(value['raw'])
        for v in value.values():collect(v)
    elif isinstance(value,list):
        for v in value:collect(v)
for p in root.rglob('*.json'):
    if 'accuracy-v7' in p.parts:continue
    try:collect(json.loads(p.read_text()))
    except (ValueError,UnicodeError):pass

cases=[];notes=[]
for i,(category,segments) in enumerate(rows,1):
    raw=''.join(text for _,text in segments)
    assert raw.isascii(),raw
    assert raw not in old_raws,raw
    assert raw not in {c['raw'] for c in cases},raw
    jp=[];en=[];offset=0
    for kind,text in segments:
        assert text
        if kind=='J':
            assert text.isalpha() and text.islower(),(i,text)
            jp.append([offset,offset+len(text)])
        elif kind=='E':en.append([offset,offset+len(text)])
        else:assert kind=='P'
        offset+=len(text)
    for ranges in [jp,en]:
        assert all(0<=a<b<=len(raw) for a,b in ranges)
    assert not any(max(a,c)<min(b,d) for a,b in jp for c,d in en)
    # Spaces are allowed only inside an authored English span, never as JP/EN boundary hints.
    assert all(any(a<=pos<b for a,b in en) for pos,ch in enumerate(raw) if ch.isspace())
    cases.append(dict(id=f'v7-final-{i:03}',raw=raw,japaneseRanges=jp,englishRanges=en))
    notes.append((i,category))
assert len(cases)==48
path=out/'final-evaluation.json'
path.write_text(json.dumps(cases,ensure_ascii=False,indent=2)+'\n')
print(json.dumps({'count':len(cases),'categories':expected,'existingDistinctRawsChecked':len(old_raws),'sha256':hashlib.sha256(path.read_bytes()).hexdigest()},indent=2))
