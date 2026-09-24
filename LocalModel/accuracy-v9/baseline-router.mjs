// Port of azooKey-Local 055b8a4. MIT; see LICENSE.txt and NOTICE.txt.
// Swift Character semantics: extended grapheme clusters, not UTF-16 offsets.
const graphemes = new Intl.Segmenter('und', {granularity:'grapheme'});
export const chars = s => Array.from(graphemes.segment(s), x=>x.segment);
const letter = c => /^[A-Za-z]$/.test(c ?? '');
const upper = c => /^\p{Uppercase}$/u.test(c ?? '');
const lowerChar = c => /^\p{Lowercase}$/u.test(c ?? '');
const number = c => /^\p{N}/u.test(c ?? '');
const whitespace = c => /^\p{White_Space}/u.test(c ?? '');
const hasUpper = s => chars(s).some(upper);
const hasNumber = s => chars(s).some(number);
const prefixes = (s,a) => a.some(x=>s.startsWith(x));
const suffixes = (s,a) => a.some(x=>s.endsWith(x));
const sigmoid = x => 1/(1+Math.exp(-Math.max(-50,Math.min(50,x))));
const particles = ['no','ni','de','wo','ha','ga','to','mo','kara','made'];
const verbs = ['shite','shita','shimasu','saremasu','suru'];
export function lex(source) {
 const c=chars(source), out=[]; let i=0;
 const starts=(s,p)=>c.slice(p,p+chars(s).length).join('')===s;
 const end=(delimiter,start)=>{let p=start;while(p<c.length){if(starts(delimiter,p))return p+chars(delimiter).length;p+=c[p]==='\\'&&!delimiter.startsWith('\\')?2:1;}return c.length;};
 const emit=(a,b,protect)=>{if(b>a)out.push({text:c.slice(a,b).join(''),protected:protect});};
 while(i<c.length){
  const start=i;let tokenEnd=i;while(tokenEnd<c.length&&!whitespace(c[tokenEnd]))tokenEnd++;
  const token=c.slice(i,tokenEnd).join('');
  if((letter(c[i])&&token.includes('@'))||starts('./',i)||starts('../',i)||starts('~/',i)||(c[i]==='/'&&letter(c[i+1]))){i=tokenEnd;emit(start,i,true);}
  else if(starts('https://',i)||starts('http://',i)){while(i<c.length&&!whitespace(c[i]))i++;emit(start,i,true);}
  else if(c[i]==='`'){i=end('`',i+1);emit(start,i,true);}
  else if(c[i]==='%'){while(i<c.length&&c[i]!=='\n')i++;emit(start,i,true);}
  else if(c[i]==='$'){const d=starts('$$',i)?'$$':'$';i=end(d,i+d.length);emit(start,i,true);}
  else if(starts('\\(',i)||starts('\\[',i)){i=end(starts('\\(',i)?'\\)':'\\]',i+2);emit(start,i,true);}
  else if(c[i]==='\\'){
   i++;if(i<c.length&&!letter(c[i])){i++;emit(start,i,true);continue;}
   while(i<c.length&&letter(c[i]))i++;
   const command=c.slice(start+1,i).join('');
   if(command==='begin'&&c[i]==='{'){
    const closing=c.indexOf('}',i);
    if(closing>=0){const env=c.slice(i+1,closing).join('');if(['equation','equation*','align','align*','gather','gather*','displaymath','math','verbatim','lstlisting'].includes(env)){i=end('\\end{'+env+'}',closing+1);emit(start,i,true);continue;}}
   }
   if(['text','section','subsection','caption','textbf','textit','emph','title'].includes(command)){emit(start,i,true);continue;}
   while(i<c.length){let a=i;while(a<c.length&&whitespace(c[a]))a++;if(a>=c.length||!['{','['].includes(c[a]))break;i=a;const open=c[i],close=open==='{'?'}':']';let depth=0;
    do{if(c[i]==='\\'){i=Math.min(c.length,i+2);continue;}if(c[i]===open)depth++;if(c[i]===close)depth--;i++;}while(i<c.length&&depth>0);
   }emit(start,i,true);
  }else if(letter(c[i])){
   while(i<c.length&&(letter(c[i])||number(c[i])||c[i]==='_'||c[i]==="'"))i++;
   let part=start;for(let p=start+1;p<i;p++){if(upper(c[p])&&lowerChar(c[p-1])&&p-part>=4){emit(part,p,false);part=p;}}emit(part,i,false);
  }else{i++;emit(start,i,true);}
 }
 return out;
}
const syllable='(?:[aeiou]|n|(?:[kgsztdnhbpmrwyfvj]|sh|ch|ts|ky|gy|ny|hy|by|py|my|ry|jy|sy|ty|dy|kw|gw|xt|lt)[aeiou]|([kstpbgdz])\\1?[aeiou])';
const complete=new RegExp('^(?:'+syllable+'|([kstpbgdz])(?=[kstpbgdz]))+$');
const partial=new RegExp('^(?:'+syllable+'|([kstpbgdz])(?=[kstpbgdz]))*(?:[kgsztdnhbpmrwyfvj]|sh|ch|ts|ky|gy|ny|hy|by|py|my|ry|jy|sy|ty|dy)?$');
const permitRomaji=/^(?:(?:[aeiou]|n|(?:[kgsztdnhbpmrwyfv]|sh|ch|ts|ky|gy|ny|hy|by|py|my|ry|jy|sy|ty|dy)[aeiou]))+$/;
export class Router {
 constructor(model){
  if(model.version!==3||!Object.keys(model.weights).length||!Object.values(model.weights).every(Number.isFinite)||model.boundaryWeights.length!==12||!model.boundaryWeights.every(Number.isFinite))throw Error('Invalid model');
  this.weights=model.weights;this.boundary=model.boundaryWeights;
  this.ambiguous=new Set(model.ambiguous);this.english=new Set(model.knownEnglish);this.japanese=new Set(model.knownJapanese);this.englishPrefixes=new Set();
  for(const w of this.english){for(let i=1;i<=w.length;i++)this.englishPrefixes.add(w.slice(0,i));}
 }
 isRomaji(w){return complete.test(w.toLowerCase());}
 isRomajiPrefix(w){return partial.test(w.toLowerCase());}
 probability(word,context=false,left='',right='',englishNeighbors=false){
  const w=word.toLowerCase(),c=chars(w),f=new Set(['bias','w:'+w,'len:'+Math.min(Math.floor(c.length/3),6)]);
  f.add(this.isRomaji(w)?'romaji-complete':this.isRomajiPrefix(w)?'romaji-prefix':'romaji-invalid');
  for(let n=1;n<=4&&c.length>=n;n++){for(let i=0;i<=c.length-n;i++)f.add('g:'+c.slice(i,i+n).join(''));f.add('p:'+c.slice(0,n).join(''));f.add('s:'+c.slice(-n).join(''));}
  if(hasUpper(word))f.add('capital');if(hasNumber(word)||word.includes('_'))f.add('identifier');
  if(englishNeighbors&&c.length<=5&&!this.ambiguous.has(w))f.add('english-neighbors');
  if(this.ambiguous.has(w)){f.add('ctx:'+w+':'+(context?'1':'0'));if(left)f.add('left:'+w+':'+left.toLowerCase());if(right)f.add('right:'+w+':'+right.toLowerCase());}
  let value=0;for(const key of f)value+=this.weights[key]??0;return sigmoid(value);
 }
 classify(raw){
  const spans=[],segmented=new Map();
  for(const span of lex(raw)){const englishPhrase=spans.length>=2&&spans.at(-1).protected&&chars(spans.at(-1).text).every(whitespace)&&this.english.has(spans.at(-2).text.toLowerCase())&&!this.ambiguous.has(spans.at(-2).text.toLowerCase());const pieces=!span.protected?this.mixedSegments(span.text,englishPhrase):null;if(pieces){if(pieces.length===2&&!pieces[0].japanese&&pieces[1].japanese){segmented.set(spans.length,chars(pieces[0].text).length);spans.push(span);}else for(const p of pieces){segmented.set(spans.length,p.japanese?0:-1);spans.push({text:p.text,protected:false});}}else spans.push(span);}
  const targets=spans.flatMap((s,i)=>s.protected?[]:[i]);
  const initial=targets.map(i=>this.probability(spans[i].text));
  const strong=(i,p)=>{const w=spans[i].text;return chars(w).length>4&&!upper(chars(w)[0])&&!this.english.has(w.toLowerCase())&&p>=.8;};
  const context=targets.some((i,n)=>strong(i,initial[n]));
  const englishCount=targets.filter(i=>this.english.has(spans[i].text.toLowerCase())&&!this.ambiguous.has(spans[i].text.toLowerCase())).length;
  const anchors=targets.filter(i=>{const w=spans[i].text.toLowerCase();return (this.japanese.has(w)&&!this.ambiguous.has(w))||(chars(w).length>=8&&this.isRomaji(w)&&suffixes(w,['masu','masen','masenn','mashita','desu','deshita','kudasai','shite','shita','nai','natta','tai','masuka','desuka','mashou']));});
  const englishSentence=englishCount>=2&&!anchors.length;
  let decisions=targets.map((index,position)=>{
   const word=spans[index].text,c=chars(word),left=position>0?spans[targets[position-1]].text:'',right=position+1<targets.length?spans[targets[position+1]].text:'',lower=word.toLowerCase(),right2=position+2<targets.length?spans[targets[position+2]].text.toLowerCase():'';
   const neighbors=position>0&&position+1<initial.length&&initial[position-1]<.2&&initial[position+1]<.2;
   const phrase=(lower==='to'&&['me','you','us','them','him','her','it'].includes(right.toLowerCase())&&!!left&&!this.japanese.has(left.toLowerCase()))||(lower==='no'&&this.english.has(right.toLowerCase())&&this.english.has(right2)&&!this.ambiguous.has(right.toLowerCase())&&!this.ambiguous.has(right2));
   const p=this.probability(word,context&&!phrase,left,right,neighbors);let offset=p>=.5?0:null,confidence=Math.max(p,1-p);
   if(this.english.has(lower)&&!this.ambiguous.has(lower))offset=null;
   if(this.englishPrefixes.has(lower)&&!this.japanese.has(lower)&&!this.ambiguous.has(lower))offset=null;
   if(upper(c[0])||word.includes('_')||word.includes("'")||hasNumber(word))offset=null;
   if(c.length<=2&&!targets.some((i,n)=>i!==index&&strong(i,initial[n])))offset=null;
   if(englishSentence&&!this.japanese.has(lower)&&!this.ambiguous.has(lower))offset=null;
   let best=-Infinity;
   if(!this.english.has(lower)&&c.length>=4){for(let split=2;split<=c.length-2;split++){
    const prefix=c.slice(0,split).join(''),suffix=c.slice(split).join('');
    if(!prefixes(suffix,['de','wo','ha','ni','ga','to','no','kara','made'])||!this.isRomaji(suffix))continue;
    if(p>.95&&!upper(chars(prefix)[0])&&this.isRomaji(prefix))continue;
    const known=this.english.has(prefix.toLowerCase());const permits=hasUpper(prefix)||hasNumber(prefix)||prefix.includes('_')||!permitRomaji.test(prefix);
    if(!known&&!permits)continue;const english=1-this.probability(prefix);if(english<.8)continue;
    const japanese=this.probability(suffix,context,prefix);if(!known&&!(split>=3&&hasUpper(prefix)))continue;
    const x=[1,+context,english,japanese,0,Math.min(split,12)/12,+hasUpper(prefix),context?english:0,Math.min(c.length-split,12)/12,+this.isRomaji(suffix),+known,this.probability(word)];
    const score=sigmoid(x.reduce((v,x,i)=>v+x*this.boundary[i],0)),utility=english+(known?.1:0)-.002*split;
    if(score>.85&&utility>best){best=utility;offset=split;confidence=score;}
   }}
   if(segmented.has(index))offset=segmented.get(index)>=0?segmented.get(index):null;
   if(offset==null&&!this.english.has(lower)){
    const acronym=word.match(/^[A-Z]*/)[0],suffix=word.slice(acronym.length);
    if(acronym.length>=2&&acronym.length<=8&&suffix.length>=4&&/^[a-z]+$/.test(suffix)&&!this.english.has(suffix)&&prefixes(suffix,['de','wo','ha','ni','ga','to','no','kara','made'])&&this.isRomaji(suffix)){
     const japanese=this.probability(suffix,true);if(japanese>=.95){offset=acronym.length;confidence=japanese;}
    }
   }
   return {index,japaneseStart:offset,probability:confidence};
  });
  const resolvedJapaneseContext=decisions.some(d=>{
   if(d.japaneseStart==null)return false;
   const suffix=chars(spans[d.index].text).slice(d.japaneseStart).join('');
   return chars(suffix).length>=4&&(this.isRomaji(suffix)||this.isRomajiPrefix(suffix))&&this.probability(suffix,true)>=.88;
  });
  if(resolvedJapaneseContext)decisions=decisions.map(d=>{
   const index=d.index,word=spans[index].text,lower=word.toLowerCase(),length=chars(word).length;
   if(d.japaneseStart!=null||segmented.has(index)||word!==lower||this.english.has(lower)||!this.isRomaji(word)||index+1>=spans.length||!spans[index+1].protected||!chars(spans[index+1].text).every(whitespace))return d;
   const contextual=this.probability(word,true);
   const particle=length<=2&&this.ambiguous.has(lower)&&contextual>=.8;
   const shortRomaji=length>=3&&length<=4&&!this.ambiguous.has(lower)&&contextual>=.25;
   return particle||shortRomaji?{index,japaneseStart:0,probability:particle?contextual:d.probability}:d;
  });
  return {spans,decisions};
 }
 mixedSegments(word,englishPhrase=false){
  // Only ASCII letters enter this routine, so JS offsets equal Swift Character offsets.
  const n=word.length,E=this.english,J=this.japanese,A=this.ambiguous,P=this.englishPrefixes;
  if(n<7||n>160||!/^[A-Za-z]+$/.test(word)||E.has(word.toLowerCase())||P.has(word.toLowerCase()))return null;
  const memo=new Map(),prob=(text,context=false)=>{const key=(context?'1:':'0:')+text;if(!memo.has(key))memo.set(key,this.probability(text,context));return memo.get(key);};
  const compound=new Map();
  for(let start=0;start<n;start++){const ends=new Set([start]),limit=Math.min(n,start+32);for(let cursor=start;cursor<limit;cursor++){if(!ends.has(cursor))continue;for(let end=cursor+1;end<=limit;end++){const p=word.slice(cursor,end).toLowerCase();if(p.length>=3&&E.has(p)&&!A.has(p))ends.add(end);}}ends.delete(start);compound.set(start,ends);}
  const englishEnds=new Set([0]);for(let start=0;start<n;start++){if(!englishEnds.has(start))continue;for(let end=start+1;end<=Math.min(n,start+32);end++){const p=word.slice(start,end).toLowerCase();if(p.length>=3&&E.has(p)&&!A.has(p))englishEnds.add(end);}}
  if(englishEnds.has(n)||[...englishEnds].some(end=>end>0&&end<n&&P.has(word.slice(end).toLowerCase())))return null;
  const strongJapaneseTail=end=>{if(!englishPhrase)return false;const suffix=word.slice(end);return suffix.length>=4&&!E.has(suffix.toLowerCase())&&prefixes(suffix,['no','ni','de','wo','ha','ga','to','mo','kara','made','shite','shita','shimas','sare','suru'])&&(this.isRomaji(suffix)||this.isRomajiPrefix(suffix))&&prob(suffix,true)>=.88;};
  const anchors=new Map();
  for(let start=0;start<n;start++){for(let end=start;end<Math.min(n,start+32);end++){
   const candidate=word.slice(start,end+1),low=candidate.toLowerCase(),lexical=compound.get(start).has(end+1),partialEnglish=end+1===n&&P.has(low);
   if(candidate.length<3||A.has(low)||J.has(low)||!(!this.isRomaji(candidate)||upper(candidate[0])||(lexical&&candidate.length>=5)||(candidate.length>=5&&prob(candidate)<.1)||(lexical&&candidate.length===4&&((start>0&&prob(candidate)<.12&&suffixes(word.slice(0,start),particles))||(start===0&&strongJapaneseTail(end+1))))))continue;
   const tail=word.slice(end+1),preceding=word.slice(0,start);
   const beforeJapanese=prefixes(tail,['no','ni','de','wo','ha','ga','to','kara','shite','shita','shimas','sare','suru'])||['n','d','w','h','g','t','k','sh','shi','sa','sar'].includes(tail);
   const afterParticle=suffixes(preceding,particles);
   const hasJapaneseSuffix=()=>{for(let split=3;split<=candidate.length-2;split++){const head=candidate.slice(0,split),rest=candidate.slice(split);if(prefixes(rest,['no','ni','de','wo','ha','ga','to','shite','shita','shimas','sare','suru'])&&this.isRomaji(rest)&&prob(head)<.4&&(prob(rest,true)>.8||verbs.some(v=>v.startsWith(rest))))return true;}return false;};
   const lexicalJapanesePrefix=J.has(preceding)||['no','ni','de','wo','ha','ga','to'].some(p=>preceding.endsWith(p)&&J.has(preceding.slice(0,-p.length)));
   let crosses=false;for(let s=start+1;s<=end;s++){if([...compound.get(s)].some(e=>e>end+1&&e-s>=4&&E.has(word.slice(s,e).toLowerCase()))){crosses=true;break;}}
   let swallows=[...compound.get(start)].some(m=>m<end+1&&prefixes(word.slice(m,end+1),particles));
   for(let m=start+1;!swallows&&m<=end;m++){if(particles.includes(word.slice(start,m))&&[...compound.get(m)].some(e=>e<=end+1))swallows=true;}
   const shortEnglishPrefix=candidate.length===3&&P.has(low)&&!this.isRomaji(candidate)&&prob(candidate)<.02&&afterParticle;
   const unknown=!lexical&&(candidate.length>=4||shortEnglishPrefix)&&candidate.length<=20&&beforeJapanese&&tail.length>=2&&(start>0||((this.isRomaji(tail)||this.isRomajiPrefix(tail))&&prob(tail,true)>=.88))&&(afterParticle||(start===0&&upper(candidate[0]))||(!this.isRomaji(candidate)&&prob(candidate)<.02))&&prob(candidate)<(lexicalJapanesePrefix?.7:.4)&&!crosses&&!swallows&&!hasJapaneseSuffix();
   if(lexical||partialEnglish||unknown){if(!anchors.has(start))anchors.set(start,[]);anchors.get(start).push({end:end+1,text:candidate});}
  }}
  if(!anchors.size)return null;
  if(this.isRomaji(word)||this.isRomajiPrefix(word)){
   const completed=[...anchors].some(([start,values])=>{const prefix=word.slice(0,start);return start>=2&&this.isRomaji(prefix)&&prob(prefix,true)>=.95&&values.some(a=>a.text.length>=5&&(E.has(a.text.toLowerCase())||(J.has(prefix)&&!this.isRomaji(a.text)&&prob(a.text)<.1&&a.end<n)));});
   const leadingEnglish=(anchors.get(0)??[]).some(a=>E.has(a.text.toLowerCase())&&(upper(a.text[0])||(a.text.length>=4&&strongJapaneseTail(a.end))));
   if(!completed&&!leadingEnglish)return null;
  }
  const phraseEvidence=new Map(),strongJapanesePhrase=(text,end)=>{
   const key=end+':'+text;if(phraseEvidence.has(key))return phraseEvidence.get(key);
   const knownBoundary=J.has(text)||particles.some(p=>{if(!text.endsWith(p))return false;const stem=text.slice(0,-p.length);return J.has(stem)||particles.some(previous=>stem.endsWith(previous)&&J.has(stem.slice(0,-previous.length)));});
   let supported=!knownBoundary&&text.length>=6&&[...particles,'ta','ru','te','nai'].some(p=>text.endsWith(p)&&this.isRomaji(text.slice(0,-p.length)))&&prob(text,true)>=.995;
   if(supported)supported=![...compound].some(([start,ends])=>start>=end-text.length&&start<end&&[...ends].some(lexicalEnd=>{const wordPart=word.slice(start,lexicalEnd).toLowerCase();return lexicalEnd-start>=4&&E.has(wordPart)&&!J.has(wordPart);}));
   phraseEvidence.set(key,supported);return supported;
  };
  const jpScores=new Map(),japaneseScore=(text,final)=>{
   if(upper(text[0])||!(this.isRomaji(text)||(final&&this.isRomajiPrefix(text))))return null;
   if(final&&['n','d','w','h','g','t','k'].includes(text))return 0;
   if(particles.includes(text))return .5;
   if(final&&text.length>=2&&verbs.some(v=>v.startsWith(text)))return text.length*.12;
   if(final&&!E.has(text.toLowerCase())&&prefixes(text,particles))return text.length*.12;
   if(!jpScores.has(text))jpScores.set(text,text.length>=4&&prob(text,true)>=.88&&!E.has(text.toLowerCase())?text.length*.12:-1);
   const score=jpScores.get(text);return score>=0?score:null;
  };
  const paths=new Map([[0,new Map([['start',{pieces:[],score:0,hasEnglish:false,hasJapanese:false}]])]]);
  const offer=(path,end,text,japanese,score)=>{
   const next={pieces:[...path.pieces,{text,japanese}],score:path.score+(score-.8),hasEnglish:path.hasEnglish||!japanese,hasJapanese:path.hasJapanese||japanese};
   const key=`${japanese}-${next.hasEnglish}-${next.hasJapanese}-${Math.min(next.pieces.length,3)}`;
   if(!paths.has(end))paths.set(end,new Map());if((paths.get(end).get(key)?.score??-Infinity)<next.score)paths.get(end).set(key,next);
  };
  for(let start=0;start<n;start++){
   const choices=paths.get(start);if(!choices)continue;
   for(const key of [...choices.keys()].sort()){
    const path=choices.get(key),last=path.pieces.at(-1);
    if(last?.japanese===true){
     const tail=word.slice(start),low=tail.toLowerCase();let stem=false;
     if(tail.length>4)for(let i=4;i<tail.length;i++){const p=tail.slice(0,i);if(E.has(p.toLowerCase())&&!this.isRomaji(p)){stem=true;break;}}
     const pending=tail.length<3&&this.isRomajiPrefix(tail)&&!upper(tail[0])&&particles.includes(last.text);
     if(!pending&&!J.has(low)&&!A.has(low)&&(P.has(low)||(stem&&prob(tail)<.4)||(!this.isRomaji(tail)&&prob(tail)<(particles.includes(last.text)?.4:.02)))){
      const evidence=E.has(low)&&particles.includes(last.text)?3+tail.length*.2:Math.min(.8,tail.length*.15);offer(path,n,tail,false,evidence);
     }
    }
    if(last?.japanese!==false){for(const a of anchors.get(start)??[]){
     const lexical=compound.get(start).has(a.end);
     if(lexical&&a.text.length===4&&this.isRomaji(a.text)&&!upper(a.text[0])){const prefix=last?.japanese===true?last.text:'';const boundary=particles.includes(prefix)||J.has(prefix)||particles.some(p=>prefix.endsWith(p)&&J.has(prefix.slice(0,-p.length)));if(!boundary&&!(start===0&&strongJapaneseTail(a.end)))continue;}
     if(!lexical&&a.text.length===3&&!(path.hasEnglish&&last?.japanese===true&&particles.includes(last.text)))continue;
     const preceding=word.slice(0,start),after=suffixes(preceding,particles);
     const jp=last?.japanese===true?last.text:'';
     const score=lexical?3+a.text.length*.2:(after||strongJapanesePhrase(jp,start))?1.5+a.text.length*.12:1-a.text.length*.06;
     let evidence=0;
     if(lexical&&jp.length>=3&&!J.has(jp)&&!suffixes(jp,particles))evidence-=3;
     if(!lexical&&a.end<n&&jp.length>=4){if(J.has(jp))evidence=2.5;else if(particles.some(p=>{if(!jp.endsWith(p))return false;const stem=jp.slice(0,-p.length);return J.has(stem)||particles.some(previous=>stem.endsWith(previous)&&J.has(stem.slice(0,-previous.length)));}))evidence=2;}
     if(a.end<n&&strongJapanesePhrase(jp,start))evidence=Math.max(evidence,2.5);
     const uncertaintyPenalty=lexical?0:.5*Math.min(.02,prob(a.text));
     offer(path,a.end,a.text,false,score+evidence-uncertaintyPenalty);
    }}
    if(last?.japanese!==true){const ends=new Set([...anchors.keys()].filter(e=>e>start));for(const p of particles){const end=start+p.length;if(end<n&&word.slice(start,end)===p)ends.add(end);}ends.add(n);
     for(const end of [...ends].sort((a,b)=>a-b)){const text=word.slice(start,end),score=japaneseScore(text,end===n);if(score!==null)offer(path,end,text,true,score);}
    }
   }
  }
  const candidates=[...(paths.get(n)?.values()??[])].filter(p=>p.hasEnglish&&p.hasJapanese&&(p.pieces.length>=3||p.pieces[0]?.japanese===true||(E.has(p.pieces[0].text.toLowerCase())&&(upper(p.pieces[0]?.text[0])||(p.pieces[0].text.length>=4&&strongJapaneseTail(p.pieces[0].text.length))))));
  candidates.sort((a,b)=>a.score-b.score||(a.pieces.map(p=>p.text).join('|')<b.pieces.map(p=>p.text).join('|')?-1:a.pieces.map(p=>p.text).join('|')>b.pieces.map(p=>p.text).join('|')?1:0));
  const best=candidates.at(-1);return best&&best.score>0?best.pieces:null;
 }
}
