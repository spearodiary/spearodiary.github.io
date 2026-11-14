window.NOTEBOOK_CONFIG={supabaseUrl:'https://x.supabase.co',supabaseAnonKey:'k'};
window.supabase={createClient(){
const DB=()=>JSON.parse(localStorage.getItem('mdb')||'{}'),SV=d=>localStorage.setItem('mdb',JSON.stringify(d));
const T=n=>{const d=DB();return d[n]||[]},ST=(n,v)=>{const d=DB();d[n]=v;SV(d)};
let sess=JSON.parse(sessionStorage.getItem('ms')||'null');const subs=[];const me=()=>sess&&sess.user.id;
const prof=o=>T('profiles').find(p=>p.user_id===o);
const canSee=o=>o===me()||!(prof(o)||{}).paused&&(T('follows').some(f=>f.follower===me()&&f.followee===o&&f.status==='accepted')||(p=>p&&p.discoverable&&!p.private)(prof(o)));
const vis=(n,r)=>n==='shared_catches'?(canSee(r.user_id)||((r.data||{}).with||[]).includes(me())):(n==='likes'||n==='comments')?canSee(r.owner):r.user_id===me();
const own=(n,r)=>n==='comments'?(r.user_id===me()||r.owner===me()):r.user_id===me();
const q=n=>{let op='select',filt=[],val=null,one=null,lim=1e9,onc=null,ord=[],rng=null,sel=false;
 const run=()=>{let all=T(n);const m=r=>filt.every(([k,f,v])=>k==='eq'?r[f]===v:k==='neq'?r[f]!==v:k==='cs'?JSON.parse(v).every(z=>((r.data||{}).with||[]).includes(z)):v.includes(r[f]));
  if(op==='select'){let rows=all.filter(r=>vis(n,r)&&m(r));if(n==='shared_catches')rows=rows.map(r=>Object.assign({caught:r.data&&r.data.date},r));ord.slice().reverse().forEach(([f,asc])=>rows.sort((a,b)=>(String(a[f]??'')<String(b[f]??'')?-1:String(a[f]??'')>String(b[f]??'')?1:0)*(asc?1:-1)));
   if(rng)rows=rows.slice(rng[0],rng[1]+1);rows=rows.slice(0,lim);if(one)return {data:rows[0]||null,error:one==='single'&&!rows[0]?{message:'none'}:null};return{data:rows,error:null}}
  if(op==='delete'){ST(n,all.filter(r=>!(own(n,r)&&m(r))));return{error:null}}
  if(op==='update'){if(n==='profiles'&&val.username&&all.some(r=>r.username===val.username&&r.user_id!==me()))return{error:{code:'23505'}};all.forEach(r=>{if(r.user_id===me()&&m(r))Object.assign(r,val)});ST(n,all);return{error:null}}
  if(op==='insert'){const row=Object.assign({},val);if(n==='profiles'){row.share=row.share||{};row.name=row.name||null;row.discoverable=false;row.private=true;row.username=null}
   if(n==='likes'||n==='comments'){row.user_id=me();row.created_at=new Date().toISOString();if(!canSee(row.owner))return{error:{message:'rls'}};if(n==='comments')row.id=Date.now()+Math.floor(Math.random()*1000)}
   all.push(row);ST(n,all);return{data:one?row:[row],error:null}}
  if(op==='upsert'){const keys=onc.split(',');all=all.filter(r=>!keys.every(k=>r[k]===val[k]));all.push(val);ST(n,all);return{error:null}}};
 const api={select(c){if(op==="select")(window.__q=window.__q||[]).push(n+":"+c);if(op==='select')op='select';else sel=true;return api},eq(f,v){filt.push(['eq',f,v]);return api},neq(f,v){filt.push(['neq',f,v]);return api},filter(f,op,v){filt.push([op,f,v]);return api},in(f,v){filt.push(['in',f,v]);return api},limit(l){lim=l;return api},range(a,b){rng=[a,b];return api},order(f,o){ord.push([f,!o||o.ascending!==false]);return api},maybeSingle(){one='maybe';return api},single(){one='single';return api},
  delete(){op='delete';return api},update(v){op='update';val=v;return api},insert(v){op='insert';val=v;return api},upsert(v,o){op='upsert';val=v;onc=o.onConflict;return api},then(res,rej){try{res(run())}catch(e){rej(e)}}};return api};
const rpc=async(fn,a)=>{const F=T('follows'),P=T('profiles');const card=p=>({id:p.user_id,username:p.username,name:p.name});
 if(fn==='my_follows')return{data:[...F.filter(f=>f.follower===me()).map(f=>Object.assign(card(prof(f.followee)||{user_id:f.followee}),{kind:'following',status:f.status,created_at:f.created_at})),...F.filter(f=>f.followee===me()).map(f=>Object.assign(card(prof(f.follower)||{user_id:f.follower}),{kind:'follower',status:f.status,created_at:f.created_at}))]};
 if(fn==='profile_cards')return{data:P.filter(p=>a.ids.includes(p.user_id)).map(card)};
 if(fn==='search_profiles'){const s=a.q.trim().toLowerCase().replace('@','');return{data:P.filter(p=>p.discoverable&&p.user_id!==me()&&((p.username||'').startsWith(s)||(p.name||'').toLowerCase().includes(s))).map(p=>Object.assign(card(p),{private:p.private,status:(F.find(f=>f.follower===me()&&f.followee===p.user_id)||{}).status||null}))}}
 if(fn==='username_free')return{data:!P.some(p=>p.username===a.u&&p.user_id!==me())};
 if(fn==='follow'){const p=prof(a.o);if(!p)return{data:'not_found'};let f=F.find(x=>x.follower===me()&&x.followee===a.o);if(!f){f={follower:me(),followee:a.o,status:p.private?'pending':'accepted',created_at:new Date().toISOString()};F.push(f);ST('follows',F)}return{data:f.status}}
 if(fn==='unfollow'){ST('follows',F.filter(f=>!(f.follower===me()&&f.followee===a.o)));return{}}
 if(fn==='follower_accept'){F.forEach(f=>{if(f.follower===a.o&&f.followee===me())f.status='accepted'});ST('follows',F);return{}}
 if(fn==='follower_remove'){ST('follows',F.filter(f=>!(f.follower===a.o&&f.followee===me())));return{}}
 if(fn==='profile_get'){const p=prof(a.o);if(!p)return{data:[]};const cs=T('shared_catches').filter(r=>r.user_id===a.o);const v=canSee(a.o);
  return{data:[Object.assign(card(p),{private:p.private,followers:F.filter(f=>f.followee===a.o&&f.status==='accepted').length,following:F.filter(f=>f.follower===a.o&&f.status==='accepted').length,fish:v?cs.reduce((s,r)=>s+(r.data.catches||[]).reduce((x,c)=>x+(c.count||1),0),0):null,status:(F.find(f=>f.follower===me()&&f.followee===a.o)||{}).status||null,follows_me:(F.find(f=>f.follower===a.o&&f.followee===me())||{}).status||null,visible:v})]}}
 return{error:{message:'nofn '+fn}}};
const PH='data:image/svg+xml;base64,'+btoa('<svg xmlns="http://www.w3.org/2000/svg" width="800" height="600"><defs><linearGradient id="g" x2="0" y2="1"><stop offset="0" stop-color="#2a8fb0"/><stop offset="1" stop-color="#0b3a4a"/></linearGradient></defs><rect width="800" height="600" fill="url(#g)"/><ellipse cx="400" cy="320" rx="190" ry="70" fill="#c9d3d6"/><path d="M570 320l90-60v120z" fill="#c9d3d6"/></svg>');
return{auth:{getSession:async()=>({data:{session:sess}}),getUser:async()=>({data:{user:sess&&sess.user}}),onAuthStateChange(f){subs.push(f)},signOut:async()=>{sessionStorage.removeItem('ms')},
 signInWithPassword:async({email})=>{sess={user:{id:'u-'+email,email}};sessionStorage.setItem('ms',JSON.stringify(sess));subs.forEach(f=>f('SIGNED_IN',sess));return{data:{session:sess,user:sess.user},error:null}}},
 from:q,rpc,channel(){return{on(){return this},subscribe(){return this}}},
 storage:{from(){return{upload:async(p,b)=>{const S=T('objs');S.push(p);ST('objs',S);return{error:null}},remove:async ps=>{ST('objs',T('objs').filter(x=>!ps.includes(x)));return{error:null}},
  createSignedUrls:async ids=>({data:ids.map(i=>({path:i,signedUrl:((i.endsWith('avatar.jpg')||i.includes('/t/'))&&!T('objs').includes(i))?null:(i.includes('/share/')&&!i.endsWith('avatar.jpg')&&!canSee(i.split('/')[0])&&!T('shared_catches').some(r=>r.user_id===i.split('/')[0]&&((r.data||{}).with||[]).includes(me())))?null:PH}))}),
  download:async(id)=>{const c=document.createElement('canvas');c.width=1200;c.height=(id.length%2)?900:1500;const x=c.getContext('2d');const g=x.createLinearGradient(0,0,0,c.height);g.addColorStop(0,'#3aa0c8');g.addColorStop(1,'#123');x.fillStyle=g;x.fillRect(0,0,c.width,c.height);x.fillStyle='#ccd';x.beginPath();x.ellipse(600,c.height/2,330,120,0,0,7);x.fill();x.fillStyle='#fff';x.font='bold 160px sans-serif';x.fillText(id.slice(-6,-4),80,200);return{data:await new Promise(r=>c.toBlob(r,'image/png'))}},list:async()=>({data:[]})}}}}}};
