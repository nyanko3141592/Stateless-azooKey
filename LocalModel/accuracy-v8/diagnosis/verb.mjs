import fs from 'node:fs';
const b='/Users/takahashinaoki/Documents/Codex/2026-09-23/azookey-web-playground/dist/';
const src=fs.readFileSync(b+'router.js','utf8'),model=JSON.parse(fs.readFileSync(b+'LocalLanguageModel.json'));
const variant=process.argv[2]??'verb';
let mod=src.replace('particles.some(p=>text.endsWith(p)&&this.isRomaji(text.slice(0,-p.length)))',"[...particles,'ta','ru','te','nai'].some(p=>text.endsWith(p)&&this.isRomaji(text.slice(0,-p.length)))");
mod=mod.replace('after?1.5+a.text.length*.12','(after||strongJapanesePhrase(last?.japanese===true?last.text:"",start))?1.5+a.text.length*.12');
const rs=[];for(const s of [src,mod]){const {Router}=await import('data:text/javascript;base64,'+Buffer.from(s).toString('base64'));rs.push(new Router(model));}
const labels=d=>d.spans.flatMap((s,i)=>Array.from(s.text,(_,p)=>!s.protected&&d.decisions.find(x=>x.index===i)?.japaneseStart!=null&&p>=d.decisions.find(x=>x.index===i).japaneseStart));
const fixtures=['accuracy-v2/fresh-evaluation.json','multiswitch-evaluation.json','release-holdout.json','accuracy-v3/fresh-evaluation.json','accuracy-v3/final-unseen.json','accuracy-v4/development.json','accuracy-v4/final-evaluation.json','accuracy-v5/fresh-evaluation.json','accuracy-v6/fresh-evaluation.json','accuracy-v6/final-evaluation.json','accuracy-v7/final-evaluation-corrected.json'];
const result=[];
for(const f of fixtures.filter(f=>!process.env.ONLY_FINAL||f.includes("accuracy-v7/"))){const cs=JSON.parse(fs.readFileSync('work/azooKey-Local/LocalModel/'+f)),ts=rs.map(()=>({exact:0,damage:0,reversals:0})),changes=[];for(const c of cs){const want=Array.from(c.raw,(_,i)=>c.japaneseRanges.some(([a,b])=>a<=i&&i<b)),ss=rs.map(r=>{let old=[],damage=0,reversals=0;for(let n=1;n<=c.raw.length;n++){const a=labels(r.classify(c.raw.slice(0,n)));if(old.some((v,i)=>v!==a[i]))reversals++;if(c.englishRanges.some(([x,y])=>y<=n&&a.slice(x,y).some(Boolean)))damage++;old=a;}return{exact:+(JSON.stringify(old)===JSON.stringify(want)),damage,reversals};});ss.forEach((s,i)=>{for(const k in s)ts[i][k]+=s[k]});if(JSON.stringify(ss[0])!==JSON.stringify(ss[1]))changes.push({raw:c.raw,stats:ss});}const row={f,stats:ts,changes};result.push(row);console.log(JSON.stringify(row));}
fs.writeFileSync('work/azooKey-Local/LocalModel/accuracy-v8/diagnosis/'+variant+'.json',JSON.stringify(result,null,2));
