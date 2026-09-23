"""Authored diagnostic corpus, fixed before evaluating the accuracy-v2 implementation.
This script is not called by training. Templates and model lexicons overlap;
these are not independent natural-language accuracy measurements.
"""
import hashlib,json
from pathlib import Path
words = 'spreadsheet clipboard checkbox dropdown tooltip breakpoint websocket webhook middleware namespace refactor staging credential telemetry avatar carousel subtitle livestream watermark playback'.split()
examples=[]
for word in words:
    examples.append([('kono',True),(word,False),('wokakuninshitekudasai',True)])
    examples.append([('ashitano',True),(word,False),('no',True),('link',False),('wookurimasu',True)])
for word in words:
    examples.append([(f'Please check the {word} before the meeting.',False)])
for raw in ['kyounoyoyakuwokakuninshitekudasai','ashitanoshiryouwojunbishimasu','raishuunouchiawasewotorikeshimasu','konohenkanhamachigatteimasu','shigotonosusumekatawominaoshitai','mousukoshimattekudasai','konokekkanitsuitesetsumeishimasu','raigetsunoyoyakuwotorinaoshimasu','tsuginojikanwoshirabeteokimasu','konoshiryouwohayakumatometekudasai']:
    examples.append([(raw,True)])
examples += [
 [('suushikiha',True),('$\\alpha+\\beta=1$',False),('desu',True)],
 [('koreha',True),('$\\int_0^1 f(x)dx$',False),('desu',True)],
 [('\\section{',False),('jikkenhouhou',True),('}',False)],
 [('\\label{sec:experiments}',False)],
 [('kono',True),('`npm run test`',False),('wotsukaimasu',True)],
 [('kono',True),('`git status --short`',False),('wotsukau',True)],
 [('renrakusakiha',True),(' hello+team@example.net ',False),('desu',True)],
 [('hozonnsakiha',True),(' ~/Downloads/report.csv ',False),('desu',True)],
 [('koreha',True),(' https://example.net/docs?a=1 ',False),('desu',True)],
 [('Please open https://example.net/docs.',False)],
]
rows=[]
for i,pieces in enumerate(examples):
    raw='';jp=[];en=[]
    for text,japanese in pieces:
        start=len(raw);raw+=text;(jp if japanese else en).append([start,len(raw)])
    rows.append(dict(id=f'accuracy-v2-{i+1:03}',raw=raw,japaneseRanges=jp,englishRanges=en))
p=Path(__file__).with_name('fresh-evaluation.json');p.write_text(json.dumps(rows,indent=2))
print(len(rows),hashlib.sha256(p.read_bytes()).hexdigest())
