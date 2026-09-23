"""Authored diagnostic cases; not used by training or inference tuning.
12 terms x 2 mixed templates, 12 English sentences, 8 Japanese, 4 protected.
"""
import json,hashlib
from pathlib import Path
words='notebook whiteboard checklist timesheet backlog roadmap flowchart wireframe prototype workbook newsfeed screencast'.split()
examples=[]
for word in words:
    examples += [[('kyouno',True),(word,False),('womisetekudasai',True)],
                 [('kono',True),(word,False),('wo',True),('Slack',False),('dekyouyuushimasu',True)]]
examples += [[(f'Could you send me the {word} today?',False)] for word in words]
examples += [[(s,True)] for s in ['kyounosagyounaiyouwokakuninshimasu','ashitanoyoyakujikanwooshietekudasai','konobunshouwohenkanshitekudasai','raishuunoyoyakuwonaoshitai','atarashiishiryouwojunbishimasu','konosetsumeiwoyomikaeshimasu','sakinikekkanokakuninwoshimasu','kinounouchiawasenonaiyouwoomoidashitai']]
examples += [[('keisanshikiha',True),('$x^2+y^2=z^2$',False),('desu',True)],
             [('\\section{',False),('kousatsunomatome',True),('}',False)],
             [('kono',True),('`git diff HEAD`',False),('wotsukaimasu',True)],
             [('renrakusakiha',True),(' editor@example.org ',False),('desu',True)]]
rows=[]
for i,pieces in enumerate(examples):
    raw='';jp=[];en=[]
    for text,j in pieces:
        start=len(raw);raw+=text;(jp if j else en).append([start,len(raw)])
    rows.append(dict(id=f'v3-fresh-{i+1:02}',raw=raw,japaneseRanges=jp,englishRanges=en))
p=Path(__file__).with_name('fresh-evaluation.json');p.write_text(json.dumps(rows,indent=2));print(len(rows),hashlib.sha256(p.read_bytes()).hexdigest())
