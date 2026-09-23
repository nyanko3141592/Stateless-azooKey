"""Reproducible, authored synthetic training corpus; no API calls or downloaded data."""
import json, random, math, hashlib, time, re
from pathlib import Path
import torch
random.seed(731); torch.manual_seed(731); torch.set_num_threads(4)
ROOT=Path(__file__).resolve().parents[1]
JP='''ashita kyou kinou raishuu senshuu konshuu asa hiru yoru watashi anata kare kanojo minna kaisha gakko uchi ie eki mise densha kuruma jitensha aruku hashiru taberu nomu miru kiku hanasu yomu kaku kau tsukau tsukuru okuru moraeru miseru wakaru shiru shiraberu kangaeru oboeru wasureru hajimeru owaru tsuzukeru naosu modoru susumu tomaru matteru kureru kudasai arigatou sumimasen onegaishimasu yoroshiku ohayou konnichiwa konbanwa sayounara doumo hai iie haihai sore kore are dore kono sono ano dono koko soko asoko nani dare doko itsu doushite douyatte moshi tatoeba demo soshite dakara sorede sorekara soreha koreha watashiha kyouha ashitaha honjitsu shigoto yotei jikan basho namae denwa renraku kaigi uchiawase gijiroku shiryou kyouyuu soufu henshin hennshin kakunin kenshou shouri mondai riyuu houhou jissou kaihatsu gakushuu keisan suushiki ronbun kekka hyouka seido sokudo henkan nyuuryoku eigo nihongo romaji bunshou moji tango koushin hozon sakujyo sakujo sentaku teisei shuusei saisei douga houkoku soudan shitsumon kotae seikou shippai tadashii machigai atarashii furui hayai osoi nagai mijikai ookii chiisai muzukashii yasashii kantan benri hitsuyou fuyou anzen anzennna teineini teinei sukoshi motto chotto takusan zenbu ichibu saisho saigo tochuu made madeni dake dakeno dakara desu deshita masu mashita masen masenn deha dewa dearu deatta shimasu shimashita shite shiteiru shiteimasu shiteokimasu shiteokimashita shitehoshii shitekudasai shitemoraemasuka shinaoshitemo shitara sureba suruto surunode shitanode detanode gadetanode deta deru tsukaenai tsukaemasen dekiru dekinai dekinakunarimashita dekinakunatta dekinakute dekimasu dekimasenn iikana deiikana sugoi iidesu yokatta yomikomi kakikomi yomikomenai hozonsuru matomete matomemasu okutte okuttemoraemasuka okuttekudasai kyouyuushiteokimasu gijirokuwomatomete ashitanouchiawasemadeni roguin roguindekinakunarimashita roguinshinaoshitemo sakinisusumemasenn tohyoujisarete hyoujisarete hennshinha mousukoshiteineinishitai sukoshimattekudasai jissoushi dekeisansuru kenshoushi hajimeni owari kyouhaiitenki arigatougozaimasu onegaidekimasuka konokekka konohenkan'''.split()
EN='''a an the this that these those I you he she we they it my your our their his her its hello goodbye thanks thank please sorry welcome good morning afternoon evening night day week month year today tomorrow yesterday meeting schedule calendar document note notes file files folder link links message reply share send receive open close save delete update edit create read write check review request response error errors problem issue fixed failed success successful wrong right expired session login logout password username account settings network connection offline online download upload install uninstall retry cancel continue next previous back forward yes true false something anything nothing everything help support work works working worked will would can could should may might must have has had do does did done be is are was were been being not no never for to from with without in on at by of as and or but if then when while until after before again more less all some any every only just very too also here there now later soon still already ready available unavailable permission denied forbidden timeout unexpected invalid valid missing required found loading conflict merge pull push fetch commit branch repository code test tests build debug release production development preview draft final version result results report reports database server client query schema table column row model token language text input output function class return import export default async await promise string number boolean object array null undefined const let var npm yarn pip python swift typescript javascript rust kotlin java ruby golang SQL HTML CSS JSON YAML XML API URL HTTP HTTPS TCP UDP CPU GPU RAM SDK IDE UI UX PR README LICENSE Google Meet Slack Notion Zoom GitHub GitLab Safari Chrome Firefox macOS Windows Linux Apple Microsoft OpenAI PyTorch TensorFlow Transformer Attention React Nextjs PostgreSQL SQLite Redis Docker Kubernetes Vercel Firebase Supabase Figma Canva Excel Word PowerPoint TypeScript JavaScript SwiftUI VSCode Homebrew git curl brew make bash zsh fish cd ls pwd grep rg cat echo touch chmod piano radio video audio media idea data made node mode todo file_name batch_size user_id no_problem log_in'''.split()
# Additional authored training vocabulary, independent of evaluation.json.
JP += """hissu hissudesu kashikomarimashita uketorimashita uketoru tsutaeru oshieru omou omotteimasu onegai onegaiitashimasu itadakemasu itadakemasuka itadakimashita saseteitadakimasu shouchishimashita ryoukaishimashita otsukaresamadesu osewaninatteorimasu konogorono saikinn nenmatsu nenhajime hiruyasumi zaitaku shukkin taikin chousa kensaku shousai setsumei shoukai shounin shinsei tetsuzuki juusho yuubin bangou tantou shiharai seikyuusho ryoukin muryou yuuryou moushikomi yoyaku torikeshi waribiki henkyaku koukan tsuika sakusei shusei henshuu henshu jikanwari yoteihyou renrakusaki bashoha kankyou settei shiyou shitai shimashou shiyoutoshitara shitakute yatteiru yattara yatteokimasu kiteiru kiteimasu tsukaeteimasu tsukaeteinai ugokanai ugokimasen ugokimasenn kidou suru shita shinai surunara shinasai surebaii surubeki minaratte kangaete kanngaete bunseki kaiseki kongetsu raigetsu sengetsu getsuyou kayou suiyou mokuyou kinyou doyou nichiyou konoaida itsumono futsuu taitei tabun hontou totsuzen tokidoki tokuni sugu zutto kitto hotondo zenzen hajimete hisashiburi tonari mukou migi hidari mannaka shita ue naka mae ushiro kokoha dokoka docchira dochira moichido mousukoshi omatase shimatte shimatta shimattara yogore koware kotaeta kaetta kaette kasureta kurabete tsunagatte kimatte onaji chigau uchiawasenaiyou yorosikune yoroshikune takahashi suzuki satou yamada tanaka""".split()
EN += """need needs needed want wants wanted take takes took taken get gets got give gives gave given see seen look looks looking find try tried trying ask asked tell told say says said know knew known think thought keep keeps kept put set run runs ran start stop change changes changed replace remove removed add added finish finished choose chosen allow allowed enable enabled disable disabled connect connected disconnect disconnected available unavailable information details address email phone contact person people team member manager customer client project plan task priority status progress notification invitation invite message attachment attached receipt order item price total amount balance date time location duration event recording transcript summary introduction conclusion feedback comment discussion answer question questions reason example sample template format content page view button menu option dialog panel window screen keyboard mouse trackpad device laptop desktop computer display monitor adapter cable charger battery power wifi internet browser website domain endpoint payload header body cookie cache storage memory disk volume backup restore recovery security privacy authentication authorization encryption certificate signature administrator owner reader writer editor viewer permission permissions access refresh expire expiration temporary permanent unlimited quota rate limit maximum minimum number count size width height depth length height weight quality accuracy confidence threshold performance throughput latency benchmark deployment environment variable parameter argument property method instance interface protocol module package dependency dependencies framework library application software hardware feature features bug bugs fix patch minor major stable beta alpha nightly preview process service worker thread queue job pipeline workflow automation action trigger source target origin destination branch branches diff history log logging timestamp timezone locale translation spelling grammar sentence paragraph chapter book paper article abstract reference citation bibliography title subtitle author published publishing publisher camera microphone speaker headphone headphones photo photograph picture image animation graphic design layout style theme color colour background foreground border shadow padding margin space spacing alignment align wrap overflow selection cursor selected visible hidden enabled disabled collapsed expanded search filter sort group split join combine compare concatenate map reduce transform convert calculate evaluate estimate approximate exact equal less greater above below between within outside across through around beside near far home house room floor door desk chair bed table kitchen garden street city country world travel flight train bus station airport hotel restaurant cafe food meal dinner breakfast lunch coffee tea water milk bread cake fruit vegetable meat fish rice salt sugar sweet hot cold warm dark light large small big little long short high low fast slow easy hard simple difficult better best worse worst nice great fine okay alright sure maybe perhaps probably certainly actually really almost enough much many few several both either neither each other another same different similar own together alone everyone someone anyone nobody themselves yourself myself herself himself ourselves business personal professional private public internal external international local remote production release tutorial guide manual instruction instructions step steps solution issue issues bug report invoice payment bill delivery shipment tracking support assistance patience effort attention review approved rejected pending complete completed incomplete necessary optional mandatory important urgent critical basic advanced standard custom random normal special unique common usual unusual precise correct incorrect proper improper natural fluent friendly polite formal informal casual happy sad birthday anniversary holiday vacation weekend weather sunny rainy snowy cloud clouds result response request success failure warning exception stack trace syntax semantic object operator operand expression statement condition loop iteration recursion concurrency parallel sequential simultaneous synchronous asynchronous cancellation fallback default override configuration preference preferences persistence stateless stateful deterministic probabilistic""".split()
JP=list(dict.fromkeys(JP)); EN=list(dict.fromkeys(EN))
SYLLABLE = r"(?:[aeiou]|n|(?:[kgsztdnhbpmrwyfvj]|sh|ch|ts|ky|gy|ny|hy|by|py|my|ry|jy|sy|ty|dy|kw|gw|xt|lt)[aeiou]|([kstpbgdz])\1?[aeiou])"
ROMAJI = re.compile(r'^(?:'+SYLLABLE+r'|([kstpbgdz])(?=[kstpbgdz]))+$')
ROMAJI_PREFIX = re.compile(r'^(?:'+SYLLABLE+r'|([kstpbgdz])(?=[kstpbgdz]))*(?:[kgsztdnhbpmrwyfvj]|sh|ch|ts|ky|gy|ny|hy|by|py|my|ry|jy|sy|ty|dy)?$')
def romaji(w):return bool(ROMAJI.fullmatch(w.lower()))

AMB=sorted(set(['no','to','de','ha','ni','ga','wo','made','ai']) | ({w.lower() for w in JP} & {w.lower() for w in EN}))
def features(word,context=False,left='',right=''):
 w=word.lower(); x={'bias','w:'+w,'len:'+str(min(len(w)//3,6))}
 x.add('romaji-complete' if romaji(w) else 'romaji-prefix' if ROMAJI_PREFIX.fullmatch(w) else 'romaji-invalid')
 for n in range(1,5):
  for i in range(len(w)-n+1):x.add('g:'+w[i:i+n])
 for n in range(1,5):
  if len(w)>=n:x.add('p:'+w[:n]);x.add('s:'+w[-n:])
 if any(c.isupper() for c in word):x.add('capital')
 if any(c.isdigit() for c in word) or '_' in word:x.add('identifier')
 if len(w)<=5 and w not in AMB and left=='@english' and right=='@english':x.add('english-neighbors')
 if w in AMB:
  x.add('ctx:'+w+':'+str(int(context)))
  if left:x.add('left:'+w+':'+left.lower())
  if right:x.add('right:'+w+':'+right.lower())
 return sorted(x)
# Target word split, before partial-prefix augmentation. Demo sentences are not the evaluation set.
rng=random.Random(731);j=list(JP);e=list(EN);rng.shuffle(j);rng.shuffle(e)
jtest=set(j[:len(j)//5])-set(AMB);etest=set(e[:len(e)//5])-set(AMB)
def corpus(words,label):
 out=[]
 for w in words:
  if w.lower() in AMB:continue
  out.append((w,label,False,'',''));out.append((w,label,True,'',''))
  # Completed words and realistically ambiguous partial keystrokes. Short fragments receive lower weight later.
  for n in range(3,len(w)):
   out.append((w[:n],label,False,'',''));out.append((w[:n],label,True,'',''))
 return out
train=corpus([x for x in JP if x not in jtest],1)+corpus([x for x in EN if x not in etest],0)
# Compositional clauses teach long and incomplete Japanese beyond memorized words.
# These authored components never consult the quality evaluation file.
parts=['kakunin','hozon','sakusei','henkou','soushin','juushin','sentaku','kensaku','chousa','shoukai','setsumei','soudan','renraku','yoyaku','henshuu','sakujo','shusei','tsuika','jikkou','kidou']
endings=['shimasu','shimashita','shitekudasai','shiteimasu','shiteokimasu','dekimasuka','dekinai','shitemoraemasuka','shitainodesuga','shitehoshiidesu','shitemo','shinaitoiwaremashita','sareteimasu','shitaidesu']
clauses=[a+b for a in parts for b in endings]
train+=corpus(clauses,1)
# Inflections around held-in Japanese words generalize noun/particle boundaries.
roots=[w for w in JP if w not in jtest and w.lower() not in {e.lower() for e in EN} and 4<=len(w)<=10]
train+=corpus([w+particle for w in roots for particle in ['ha','wo','ni','no','de','ga']],1)
test=corpus(sorted(jtest),1)+corpus(sorted(etest),0)
for _ in range(30):
 for w in AMB:
  train += [(w,1,True,'',''),(w,0,False,'','')]
 for w,nxt in [('no','problem'),('no','errors'),('to','the'),('to','you'),('made','in')]:
  train += [(w,0,False,'',nxt),(w,0,True,'',nxt)]
 for w in ['wo','ha','ni','ga','de']:
  train += [(w,1,True,'API','shimasu')]
# Explicitly authored general grammatical pairs, not captured API responses.
for _ in range(8):
 for w in EN:
  if w not in etest and w.lower() not in AMB and len(w)<=5:
   train += [(w,0,True,'@english','@english')]
# Exclude held-out complete spellings even if generated as a prefix of another training word.
held_out_spellings={w.lower() for w in jtest|etest}
train=[row for row in train if row[0].lower() not in held_out_spellings]
vocab=sorted({f for w,_,c,l,r in train for f in features(w,c,l,r)})
ids={f:i for i,f in enumerate(vocab)}
rows=[[ids[f] for f in features(w,c,l,r) if f in ids] for w,_,c,l,r in train]
model=torch.nn.EmbeddingBag(len(vocab),1,mode='sum');torch.nn.init.zeros_(model.weight)
opt=torch.optim.Adam(model.parameters(),lr=.025,weight_decay=.00005)
start=time.time()
for epoch in range(45):
 order=list(range(len(train)));rng.shuffle(order)
 for off in range(0,len(order),256):
  batch=order[off:off+256];flat=[];offset=[]
  for i in batch:offset.append(len(flat));flat+=rows[i]
  pred=model(torch.tensor(flat),torch.tensor(offset)).flatten()
  y=torch.tensor([float(train[i][1]) for i in batch])
  loss=torch.nn.functional.binary_cross_entropy_with_logits(pred,y)
  opt.zero_grad();loss.backward();opt.step()
weights={f:round(float(model.weight[i,0].detach()),7) for f,i in ids.items()}
def prob(w,c=False,l='',r=''):
 v=sum(weights.get(f,0) for f in features(w,c,l,r));return 1/(1+math.exp(-max(-50,min(50,v))))
full=[(w,1,c,'','') for w in sorted(jtest) for c in [False,True]]+[(w,0,c,'','') for w in sorted(etest) for c in [False,True]]
train_spellings={x[0].lower() for x in train}
unseen_prefix=[x for x in test if x[0].lower() not in train_spellings]
report={'architecture':'trained character 1-4gram + word/shape/context logistic classifier','seed':731,'trainRows':len(train),'features':len(vocab),'heldOutWords':len(jtest)+len(etest),'heldOutFullTokenAccuracy':sum((prob(w,c,l,r)>=.5)==bool(y) for w,y,c,l,r in full)/len(full),'unseenPrefixAccuracy':sum((prob(w,c,l,r)>=.5)==bool(y) for w,y,c,l,r in unseen_prefix)/len(unseen_prefix),'seconds':time.time()-start,'limitations':'Authored synthetic lexicon; held-out words from same author/distribution. Not natural-text benchmark. Short prefixes inherently ambiguous.'}
# Train a second tiny classifier for English-prefix + Japanese-particle boundaries.
known=sorted({w.lower() for w in EN if w not in etest})
known_set=set(known)
suffixes=['de','wo','ha','ni','ga','to','no','kara','made','desu']
boundary_suffixes=suffixes+['de'+x for x in clauses[::17]]+['no'+x for x in clauses[::19]]+['wo'+x for x in clauses[::23]]+['ni'+x for x in clauses[::29]]
def boundary_features(word,offset,context):
 prefix=word[:offset];suffix=word[offset:]
 ep=1-prob(prefix);jp=prob(suffix,context,prefix,'')
 return [1.0,float(context),ep,jp,float(word.lower() in known_set),min(len(prefix),12)/12,float(any(c.isupper() for c in prefix)),float(context)*ep, min(len(suffix),12)/12, float(romaji(suffix)), float(prefix.lower() in known_set), prob(word)]
bx=[];by=[]
for word in EN:
 if word in etest or len(word)<3 or not word.isalpha():continue
 for suffix in boundary_suffixes:
  combined=word+suffix
  bx.append(boundary_features(combined,len(word),True));by.append(1.0)
  bx.append(boundary_features(combined,len(word),False));by.append(float(len(suffix)>4))
for word in [w for w in JP+EN if w not in jtest and w not in etest]:
 for suffix in suffixes:
  if word.endswith(suffix) and len(word)>len(suffix)+1:
   for ctx in [False,True]:
    bx.append(boundary_features(word,len(word)-len(suffix),ctx));by.append(0.0)
X=torch.tensor(bx);Y=torch.tensor(by);bw=torch.zeros(12,requires_grad=True);bo=torch.optim.Adam([bw],lr=.06)
for _ in range(600):
 loss=torch.nn.functional.binary_cross_entropy_with_logits(X@bw,Y)+.0002*(bw*bw).sum()
 bo.zero_grad();loss.backward();bo.step()
boundary_weights=[round(float(x),7) for x in bw.detach()]
report['boundaryTrainingRows']=len(by)
report['routingNote']='The shipping router also uses the full authored English/Japanese lexicons. Token holdout scores evaluate raw classifier probabilities only, not the lexicon-assisted router. Sentence evaluation has vocabulary overlap.'
out=ROOT/'Core/Sources/Core/Resources/LocalLanguageModel.json'
out.write_text(json.dumps({'version':3,'weights':weights,'ambiguous':AMB,'boundaryWeights':boundary_weights,'knownEnglish':sorted({w.lower() for w in EN}),'knownJapanese':sorted({w.lower() for w in JP})},ensure_ascii=False,separators=(',',':')))
report['sha256']=hashlib.sha256(out.read_bytes()).hexdigest();report['bytes']=out.stat().st_size
(ROOT/'LocalModel/training-report.json').write_text(json.dumps(report,indent=2))
(ROOT/'LocalModel/split.json').write_text(json.dumps({'heldOutJapanese':sorted(jtest),'heldOutEnglish':sorted(etest)},indent=2))
parity=[]
for w,c,l,r in [('Google',True,'',''),('no',True,'Meet','URL'),('no',True,'','errors'),('no',False,'',''),('Reactde',True,'',''),('Meetno',True,'',''),('gadetanode',True,'','')]:
 parity.append(dict(word=w,context=c,left=l,right=r,probability=prob(w,c,l,r)))
(ROOT/'LocalModel/parity.json').write_text(json.dumps(parity,indent=2))
print(json.dumps(report,indent=2));print(json.dumps(parity,indent=2))
