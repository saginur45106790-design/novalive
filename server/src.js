import 'dotenv/config';
import crypto from 'node:crypto';
import express from 'express';
import helmet from 'helmet';
import rateLimit from 'express-rate-limit';
import bcrypt from 'bcryptjs';
import jwt from 'jsonwebtoken';
import pg from 'pg';
import {AccessToken, RoomServiceClient} from 'livekit-server-sdk';

for (const k of ['DATABASE_URL','JWT_SECRET','LIVEKIT_URL','LIVEKIT_HTTP_URL','LIVEKIT_API_KEY','LIVEKIT_API_SECRET']) {
  if (!process.env[k]) throw Error(`Missing ${k}`);
}
if (process.env.JWT_SECRET.length < 32) throw Error('JWT_SECRET must be >=32 chars');
const db = new pg.Pool({connectionString:process.env.DATABASE_URL, max:12, ssl:process.env.DATABASE_URL.includes('localhost')?false:{rejectUnauthorized:true}});
const media = new RoomServiceClient(process.env.LIVEKIT_HTTP_URL,process.env.LIVEKIT_API_KEY,process.env.LIVEKIT_API_SECRET);
const app = express();
app.disable('x-powered-by');
app.set('trust proxy',1);
app.use(helmet());
app.use(express.json({limit:'40kb'}));
app.use(rateLimit({windowMs:60_000,limit:120,standardHeaders:'draft-7',legacyHeaders:false}));
const api = express.Router();
app.use('/api',api);
app.use('/admin',express.static('public',{index:'index.html'}));
app.get('/', (_req,res)=>res.redirect('/admin'));
app.get('/health',(_req,res)=>res.json({ok:true,service:'novalive',time:new Date().toISOString()}));
app.get('/health/ready', async (_req,res)=>{
 try { await db.query('SELECT 1'); res.json({ok:true,service:'novalive',database:'reachable'}); }
 catch (_) { res.status(503).json({ok:false,service:'novalive',database:'unavailable'}); }
});
const wrap = f => (req,res,next) => Promise.resolve(f(req,res,next)).catch(next);
const fail = (code,message) => { const e = Error(message); e.status=code; throw e; };
const str=(v,max=100)=>typeof v==='string'?v.trim().slice(0,max):'';
const isUUID=v=>typeof v==='string' && /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i.test(v);
const positiveInt=v=>Number.isSafeInteger(v)&&v>0;
const selectUser='id,name,email,role,coins,earnings,bio,created_at';
async function actor(req,_res,next){
 try {
  const token=req.headers.authorization?.replace(/^Bearer /i,'');
  if(!token) return fail(401,'Login required');
  const payload=jwt.verify(token,process.env.JWT_SECRET,{algorithms:['HS256']});
  const q=await db.query(`SELECT ${selectUser}, suspended FROM users WHERE id=$1`,[payload.sub]);
  if(!q.rowCount || q.rows[0].suspended) return fail(401,'Account unavailable');
  req.user=q.rows[0]; next();
 }catch(e){next(e.status?e:Object.assign(Error('Invalid or expired session'),{status:401}));}
}
const admin=(req,_res,next)=>req.user.role==='admin'?next():next(Object.assign(Error('Admin only'),{status:403}));
const authLimit=rateLimit({windowMs:15*60_000,limit:15,standardHeaders:'draft-7',legacyHeaders:false});
const audit=async (client,actorId,action,targetId,details={})=>client.query('INSERT INTO audit_log(actor_id,action,target_id,details) VALUES($1,$2,$3,$4)',[actorId,action,targetId,JSON.stringify(details)]);
async function transaction(fn){const cx=await db.connect();try{await cx.query('BEGIN');const value=await fn(cx);await cx.query('COMMIT');return value;}catch(e){await cx.query('ROLLBACK');throw e;}finally{cx.release();}}
async function grant(userId,roomName,canPublish,kind='live'){
 const token=new AccessToken(process.env.LIVEKIT_API_KEY,process.env.LIVEKIT_API_SECRET,{identity:userId,ttl:kind==='private'?'10m':'1h'});
 token.addGrant({room:roomName,roomJoin:true,roomCreate:false,canPublish,canSubscribe:true,canPublishData:true});
 return {url:process.env.LIVEKIT_URL,token:await token.toJwt()};
}
const roomName=id=>`nova-${id}`;
async function blocked(a,b){const r=await db.query('SELECT 1 FROM blocks WHERE (owner_id=$1 AND blocked_id=$2) OR (owner_id=$2 AND blocked_id=$1) LIMIT 1',[a,b]);return r.rowCount>0;}

api.post('/auth/register',authLimit,wrap(async(req,res)=>{
 const name=str(req.body.name,60), email=str(req.body.email,254).toLowerCase();
 const password=req.body.password,age=req.body.ageConfirmed===true;
 if(name.length<2||!/^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(email)||typeof password!=='string'||password.length<10||password.length>128||!age) return fail(400,'Valid name, email, password (10+ chars), and 18+ confirmation required');
 const hash=await bcrypt.hash(password,12);
 try{const r=await db.query('INSERT INTO users(name,email,password_hash,age_confirmed) VALUES($1,$2,$3,true) RETURNING id,name,email,role,coins,earnings,bio',[name,email,hash]);
 const u=r.rows[0];res.status(201).json({user:u,token:jwt.sign({sub:u.id},process.env.JWT_SECRET,{expiresIn:'7d',algorithm:'HS256'})});}
 catch(e){if(e.code==='23505') return fail(409,'Email already registered');throw e;}
}));
api.post('/auth/login',authLimit,wrap(async(req,res)=>{
 const email=str(req.body.email,254).toLowerCase(),password=req.body.password;
 const q=await db.query('SELECT * FROM users WHERE email=$1',[email]);
 if(!q.rowCount||typeof password!=='string'||!await bcrypt.compare(password,q.rows[0].password_hash)||q.rows[0].suspended) return fail(401,'Invalid credentials');
 const u=q.rows[0];res.json({user:{id:u.id,name:u.name,email:u.email,role:u.role,coins:u.coins,earnings:u.earnings,bio:u.bio},token:jwt.sign({sub:u.id},process.env.JWT_SECRET,{expiresIn:'7d',algorithm:'HS256'})});
}));

// Browse before login. No email, wallet, phone, location or private account fields are exposed.
// Public hosts are only accounts individually promoted to 'host' by an administrator.
const publicBrowseLimit=rateLimit({windowMs:60_000,limit:45,standardHeaders:'draft-7',legacyHeaders:false});
const guestWatchLimit=rateLimit({windowMs:10*60_000,limit:18,standardHeaders:'draft-7',legacyHeaders:false});
api.get('/public/discover',publicBrowseLimit,wrap(async(_req,res)=>{
  res.set('Cache-Control','no-store');
  const [hosts,rooms]=await Promise.all([
    db.query("SELECT id,name,bio FROM users WHERE role='host' AND suspended=false ORDER BY created_at DESC LIMIT 30"),
    db.query("SELECT r.id,r.title,u.name AS owner_name FROM rooms r JOIN users u ON r.owner_id=u.id WHERE r.status='active' AND r.kind='live' AND u.suspended=false AND u.role='host' ORDER BY r.created_at DESC LIMIT 40")
  ]);
  res.json({hosts:hosts.rows,rooms:rooms.rows});
}));
// Guest can ONLY subscribe to a public live room. Never allow camera, mic, data or call access.
api.post('/public/rooms/:id/watch',guestWatchLimit,wrap(async(req,res)=>{
  if(!isUUID(req.params.id))return fail(400,'Invalid room');
  const q=await db.query("SELECT r.id FROM rooms r JOIN users u ON r.owner_id=u.id WHERE r.id=$1 AND r.kind='live' AND r.status='active' AND u.suspended=false AND u.role='host'",[req.params.id]);
  if(!q.rowCount)return fail(404,'Public live room unavailable');
  const token=new AccessToken(process.env.LIVEKIT_API_KEY,process.env.LIVEKIT_API_SECRET,{
    identity:`guest-${crypto.randomUUID()}`,ttl:'30m'
  });
  token.addGrant({room:roomName(q.rows[0].id),roomJoin:true,roomCreate:false,
    canPublish:false,canSubscribe:true,canPublishData:false});
  res.set('Cache-Control','no-store');
  res.json({url:process.env.LIVEKIT_URL,token:await token.toJwt()});
}));

api.use(actor);
api.get('/me',(req,res)=>res.json({user:req.user}));
api.patch('/me',wrap(async(req,res)=>{
 const name=str(req.body.name,60),bio=str(req.body.bio,400);
 if(name.length<2)return fail(400,'Name too short');
 const r=await db.query(`UPDATE users SET name=$1,bio=$2 WHERE id=$3 RETURNING ${selectUser}`,[name,bio,req.user.id]);res.json({user:r.rows[0]});
}));
api.get('/people',wrap(async(req,res)=>{
 const q=await db.query(`SELECT id,name,role,bio,created_at FROM users WHERE suspended=false AND id<>$1 AND role<>'admin' AND NOT EXISTS (SELECT 1 FROM blocks WHERE (owner_id=$1 AND blocked_id=users.id) OR (owner_id=users.id AND blocked_id=$1)) ORDER BY CASE WHEN role='host' THEN 0 ELSE 1 END,created_at DESC LIMIT 100`,[req.user.id]);
 res.json({people:q.rows});
}));
api.post('/block/:id',wrap(async(req,res)=>{
 if(!isUUID(req.params.id)||req.params.id===req.user.id)return fail(400,'Invalid person');
 await db.query('INSERT INTO blocks(owner_id,blocked_id) VALUES($1,$2) ON CONFLICT DO NOTHING',[req.user.id,req.params.id]);res.json({ok:true});
}));
api.delete('/block/:id',wrap(async(req,res)=>{await db.query('DELETE FROM blocks WHERE owner_id=$1 AND blocked_id=$2',[req.user.id,req.params.id]);res.json({ok:true});}));
api.post('/reports',wrap(async(req,res)=>{
 const target=req.body.targetId,reason=str(req.body.reason,250);
 if(!isUUID(target)||reason.length<8||target===req.user.id)return fail(400,'Invalid report');
 await db.query('INSERT INTO reports(reporter_id,target_id,reason) VALUES($1,$2,$3)',[req.user.id,target,reason]);res.status(201).json({ok:true});
}));
api.get('/chats',wrap(async(req,res)=>{
 const r=await db.query(`SELECT DISTINCT ON (partner_id) partner_id,other_name,body,created_at FROM (
 SELECT CASE WHEN sender_id=$1 THEN recipient_id ELSE sender_id END partner_id,
 CASE WHEN sender_id=$1 THEN b.name ELSE a.name END other_name,m.body,m.created_at
 FROM messages m JOIN users a ON a.id=m.sender_id JOIN users b ON b.id=m.recipient_id
 WHERE sender_id=$1 OR recipient_id=$1 ) t ORDER BY partner_id,created_at DESC LIMIT 60`,[req.user.id]);res.json({chats:r.rows});
}));
api.get('/chats/:id',wrap(async(req,res)=>{
 const id=req.params.id;if(!isUUID(id))return fail(400,'Invalid ID');
 const r=await db.query(`SELECT id,sender_id,recipient_id,body,created_at FROM messages WHERE (sender_id=$1 AND recipient_id=$2) OR (sender_id=$2 AND recipient_id=$1) ORDER BY created_at DESC LIMIT 100`,[req.user.id,id]);res.json({messages:r.rows.reverse()});
}));
api.post('/chats/:id',wrap(async(req,res)=>{
 const id=req.params.id,body=str(req.body.body,2000);
 if(!isUUID(id)||id===req.user.id||!body)return fail(400,'Invalid message');
 if(await blocked(req.user.id,id))return fail(403,'Chat blocked');
 const r=await db.query('INSERT INTO messages(sender_id,recipient_id,body) VALUES($1,$2,$3) RETURNING *',[req.user.id,id,body]);res.status(201).json({message:r.rows[0]});
}));
// A call invitation must be accepted before either participant receives a media token.
api.post('/calls',wrap(async(req,res)=>{
 const target=req.body.targetId;
 if(!isUUID(target)||target===req.user.id)return fail(400,'Invalid callee');
 if(await blocked(req.user.id,target))return fail(403,'Blocked user');
 const person=await db.query("SELECT id FROM users WHERE id=$1 AND suspended=false AND role<>'admin'",[target]);
 if(!person.rowCount)return fail(404,'Person not found');
 const out=await transaction(async cx=>{
  const room=await cx.query("INSERT INTO rooms(owner_id,kind,title) VALUES($1,'private','Private call') RETURNING id",[req.user.id]);
  const call=await cx.query('INSERT INTO calls(caller_id,callee_id,room_id) VALUES($1,$2,$3) RETURNING id,status,created_at',[req.user.id,target,room.rows[0].id]);return call.rows[0];
 });res.status(201).json({call:out});
}));
api.get('/calls/incoming',wrap(async(req,res)=>{
 await db.query("UPDATE calls SET status='ended', ended_at=now() WHERE status='ringing' AND created_at < now()-interval '90 seconds'");
 const r=await db.query("SELECT c.id,c.caller_id,c.created_at,u.name caller_name FROM calls c JOIN users u ON u.id=c.caller_id WHERE c.callee_id=$1 AND c.status='ringing' ORDER BY c.created_at DESC LIMIT 10",[req.user.id]);res.json({calls:r.rows});
}));
api.get('/calls/outgoing/:id',wrap(async(req,res)=>{
 const r=await db.query('SELECT id,status FROM calls WHERE id=$1 AND caller_id=$2',[req.params.id,req.user.id]);if(!r.rowCount)return fail(404,'Call missing');res.json({call:r.rows[0]});
}));
api.post('/calls/:id/answer',wrap(async(req,res)=>{
 const accept=req.body.accept===true;
 const r=await db.query("SELECT * FROM calls WHERE id=$1 AND callee_id=$2 AND status='ringing' AND created_at>now()-interval '90 seconds'",[req.params.id,req.user.id]);
 if(!r.rowCount)return fail(409,'Call unavailable or expired');
 if(accept){await media.createRoom({name:roomName(r.rows[0].room_id),emptyTimeout:30,maxParticipants:2});}
 const q=await db.query("UPDATE calls SET status=$1,started_at=CASE WHEN $1='accepted' THEN now() ELSE started_at END WHERE id=$2 AND callee_id=$3 AND status='ringing' RETURNING id,status",[accept?'accepted':'rejected',req.params.id,req.user.id]);
 if(!q.rowCount)return fail(409,'Call already answered');res.json({call:q.rows[0]});
}));
api.get('/calls/:id/token',wrap(async(req,res)=>{
 const r=await db.query("SELECT c.*,r.status room_status FROM calls c JOIN rooms r ON r.id=c.room_id WHERE c.id=$1 AND (c.caller_id=$2 OR c.callee_id=$2)",[req.params.id,req.user.id]);
 if(!r.rowCount||r.rows[0].status!=='accepted'||r.rows[0].room_status!=='active')return fail(403,'Call not accepted or ended');
 res.json(await grant(req.user.id,roomName(r.rows[0].room_id),true,'private'));
}));
api.post('/calls/:id/end',wrap(async(req,res)=>{
 const r=await db.query("UPDATE calls SET status='ended',ended_at=now() WHERE id=$1 AND (caller_id=$2 OR callee_id=$2) AND status IN('ringing','accepted') RETURNING room_id",[req.params.id,req.user.id]);
 if(r.rowCount){await db.query("UPDATE rooms SET status='closed' WHERE id=$1",[r.rows[0].room_id]);try{await media.deleteRoom(roomName(r.rows[0].room_id));}catch(_){/* room may never have started */}}
 res.json({ok:true});
}));
api.get('/rooms',wrap(async(req,res)=>{
 const r=await db.query("SELECT r.id,r.kind,r.title,r.owner_id,u.name owner_name,r.created_at FROM rooms r JOIN users u ON r.owner_id=u.id WHERE r.status='active' AND r.kind IN('live','party') ORDER BY r.created_at DESC LIMIT 100");res.json({rooms:r.rows});
}));
api.post('/rooms',wrap(async(req,res)=>{
 const kind=req.body.kind,title=str(req.body.title,100);
 if(!['party','live'].includes(kind)||title.length<3)return fail(400,'Invalid room');
 if(req.user.role!=='host'&&req.user.role!=='admin')return fail(403,'Approved hosts only');
 const id=crypto.randomUUID();await media.createRoom({name:roomName(id),emptyTimeout:600,maxParticipants:kind==='party'?12:250});
 try{await db.query("INSERT INTO rooms(id,owner_id,kind,title) VALUES($1,$2,$3,$4)",[id,req.user.id,kind,title]);}
 catch(e){await media.deleteRoom(roomName(id)).catch(()=>{});throw e;}
 res.status(201).json({room:{id,kind,title}});
}));
api.post('/rooms/:id/token',wrap(async(req,res)=>{
 const r=await db.query("SELECT * FROM rooms WHERE id=$1 AND status='active' AND kind IN('party','live')",[req.params.id]);
 if(!r.rowCount)return fail(404,'Room not available');
 if(await blocked(req.user.id,r.rows[0].owner_id))return fail(403,'Room blocked');
 const publish=r.rows[0].kind==='party'||r.rows[0].owner_id===req.user.id;
 res.json(await grant(req.user.id,roomName(r.rows[0].id),publish,r.rows[0].kind));
}));
api.post('/rooms/:id/close',wrap(async(req,res)=>{
 const r=await db.query("UPDATE rooms SET status='closed' WHERE id=$1 AND (owner_id=$2 OR $3='admin') AND status='active' RETURNING id",[req.params.id,req.user.id,req.user.role]);
 if(!r.rowCount)return fail(404,'Room unavailable');await media.deleteRoom(roomName(req.params.id)).catch(()=>{});res.json({ok:true});
}));
// Coins are never minted by clients. A separately verified payment provider must be connected before public top-ups.
api.get('/wallet',wrap(async(req,res)=>{
 const q=await db.query('SELECT coins,earnings FROM users WHERE id=$1',[req.user.id]);
 const h=await db.query('SELECT id,coin_delta,earning_delta,action,created_at FROM ledger WHERE user_id=$1 ORDER BY created_at DESC LIMIT 50',[req.user.id]);res.json({wallet:q.rows[0],history:h.rows});
}));
const GIFT_PRICES={rose:10,star:50,heart:100,crown:500};
api.get('/gifts',(_req,res)=>res.json({gifts:GIFT_PRICES}));
api.post('/gifts',wrap(async(req,res)=>{
 const recipient=req.body.recipientId,key=req.body.giftKey,price=GIFT_PRICES[key];
 if(!isUUID(recipient)||recipient===req.user.id||!price)return fail(400,'Invalid gift');
 if(await blocked(req.user.id,recipient))return fail(403,'Gift blocked');
 const data=await transaction(async cx=>{
  const lock=await cx.query('SELECT id,coins,role FROM users WHERE id=ANY($1::uuid[]) ORDER BY id FOR UPDATE',[[recipient,req.user.id]]);
  if(lock.rowCount!==2)return fail(404,'Person missing');
  const sender=lock.rows.find(x=>x.id===req.user.id),host=lock.rows.find(x=>x.id===recipient);
  if(sender.coins<price)return fail(409,'Insufficient coins');
  if(!['host','admin'].includes(host.role))return fail(403,'Only verified hosts receive gifts');
  await cx.query('UPDATE users SET coins=coins-$1 WHERE id=$2',[price,req.user.id]);
  const earned=Math.floor(price*70/100);
  await cx.query('UPDATE users SET earnings=earnings+$1 WHERE id=$2',[earned,recipient]);
  const gift=await cx.query('INSERT INTO gifts(sender_id,recipient_id,gift_key,price) VALUES($1,$2,$3,$4) RETURNING id',[req.user.id,recipient,key,price]);
  await cx.query('INSERT INTO ledger(user_id,coin_delta,earning_delta,action,reference_id) VALUES($1,$2,0,$3,$4),($5,0,$6,$7,$4)',[req.user.id,-price,'gift_sent',gift.rows[0].id,recipient,earned,'gift_received']);
  return {giftId:gift.rows[0].id,price,earned};
 });res.status(201).json(data);
}));
api.post('/wallet/withdraw',wrap(async(req,res)=>{
 const points=req.body.points,details=str(req.body.payoutDetails,250);
 if(!positiveInt(points)||points<1000||details.length<8)return fail(400,'Minimum 1000 earnings points and valid payout details required');
 const data=await transaction(async cx=>{
  const user=await cx.query('SELECT earnings FROM users WHERE id=$1 FOR UPDATE',[req.user.id]);
  if(user.rows[0].earnings<points)return fail(409,'Insufficient points');
  await cx.query('UPDATE users SET earnings=earnings-$1 WHERE id=$2',[points,req.user.id]);
  const r=await cx.query('INSERT INTO withdrawals(user_id,points,payout_details) VALUES($1,$2,$3) RETURNING id,status',[req.user.id,points,details]);
  await cx.query('INSERT INTO ledger(user_id,earning_delta,action,reference_id) VALUES($1,$2,$3,$4)',[req.user.id,-points,'withdraw_requested',r.rows[0].id]);return r.rows[0];
 });res.status(201).json({withdrawal:data});
}));
api.get('/wallet/withdrawals',wrap(async(req,res)=>{
 const r=await db.query('SELECT id,points,status,created_at,settled_at FROM withdrawals WHERE user_id=$1 ORDER BY created_at DESC LIMIT 50',[req.user.id]);res.json({withdrawals:r.rows});
}));
api.use('/admin',admin);
api.get('/admin/overview',wrap(async(req,res)=>{
 const [users,rooms,reports,payouts]=await Promise.all([
  db.query('SELECT count(*)::int count FROM users'),db.query("SELECT count(*)::int count FROM rooms WHERE status='active'"),db.query("SELECT count(*)::int count FROM reports WHERE state='open'"),db.query("SELECT count(*)::int count FROM withdrawals WHERE status='pending'")]);
 res.json({users:users.rows[0].count,liveRooms:rooms.rows[0].count,openReports:reports.rows[0].count,pendingWithdrawals:payouts.rows[0].count});
}));
api.get('/admin/users',wrap(async(req,res)=>{const r=await db.query(`SELECT ${selectUser},suspended FROM users ORDER BY created_at DESC LIMIT 200`);res.json({users:r.rows});}));
api.post('/admin/users/:id/role',wrap(async(req,res)=>{
 if(!['user','host'].includes(req.body.role)||!isUUID(req.params.id))return fail(400,'Bad role');
 const r=await transaction(async cx=>{const q=await cx.query("UPDATE users SET role=$1 WHERE id=$2 AND role<>'admin' RETURNING id",[req.body.role,req.params.id]);if(!q.rowCount)return fail(404,'User not found');await audit(cx,req.user.id,'user_role',req.params.id,{role:req.body.role});return q.rows[0];});res.json({user:r});
}));
api.post('/admin/users/:id/suspend',wrap(async(req,res)=>{
 if(!isUUID(req.params.id)||req.params.id===req.user.id||typeof req.body.suspended!=='boolean')return fail(400,'Invalid request');
 await transaction(async cx=>{const q=await cx.query("UPDATE users SET suspended=$1 WHERE id=$2 AND role<>'admin' RETURNING id",[req.body.suspended,req.params.id]);if(!q.rowCount)return fail(404,'User unavailable');await audit(cx,req.user.id,'user_suspension',req.params.id,{suspended:req.body.suspended});});res.json({ok:true});
}));
api.post('/admin/users/:id/credit',wrap(async(req,res)=>{
 // Administrative reconciliation ONLY, not a client payment endpoint.
 const amount=req.body.coins,reference=str(req.body.verifiedPaymentReference,80);
 if(!isUUID(req.params.id)||!positiveInt(amount)||amount>100000||reference.length<10)return fail(400,'Must provide positive coins and verified external payment reference');
 await transaction(async cx=>{
  const q=await cx.query('UPDATE users SET coins=coins+$1 WHERE id=$2 RETURNING id',[amount,req.params.id]);if(!q.rowCount)return fail(404,'User unavailable');
  await cx.query('INSERT INTO ledger(user_id,coin_delta,action) VALUES($1,$2,$3)',[req.params.id,amount,'admin_reconcile']);await audit(cx,req.user.id,'coin_reconcile',req.params.id,{amount,reference});
 });res.json({ok:true});
}));
api.get('/admin/reports',wrap(async(req,res)=>{const r=await db.query('SELECT r.*,a.name reporter_name,b.name target_name FROM reports r JOIN users a ON a.id=r.reporter_id JOIN users b ON b.id=r.target_id ORDER BY created_at DESC LIMIT 100');res.json({reports:r.rows});}));
api.post('/admin/reports/:id/resolve',wrap(async(req,res)=>{await db.query("UPDATE reports SET state='resolved' WHERE id=$1",[req.params.id]);res.json({ok:true});}));
api.get('/admin/withdrawals',wrap(async(req,res)=>{const r=await db.query('SELECT w.*,u.email,u.name FROM withdrawals w JOIN users u ON u.id=w.user_id ORDER BY created_at DESC LIMIT 100');res.json({withdrawals:r.rows});}));
api.post('/admin/withdrawals/:id/settle',wrap(async(req,res)=>{
 const status=req.body.status;if(!['paid','rejected'].includes(status))return fail(400,'Invalid status');
 await transaction(async cx=>{
  const q=await cx.query('SELECT * FROM withdrawals WHERE id=$1 FOR UPDATE',[req.params.id]);if(!q.rowCount||q.rows[0].status!=='pending')return fail(409,'Withdrawal already settled or missing');
  const w=q.rows[0];if(status==='rejected'){
   await cx.query('UPDATE users SET earnings=earnings+$1 WHERE id=$2',[w.points,w.user_id]);
   await cx.query('INSERT INTO ledger(user_id,earning_delta,action,reference_id) VALUES($1,$2,$3,$4)',[w.user_id,w.points,'withdraw_rejected',w.id]);
  }
  await cx.query('UPDATE withdrawals SET status=$1,settled_at=now() WHERE id=$2',[status,w.id]);await audit(cx,req.user.id,'withdraw_'+status,w.user_id,{withdrawalId:w.id,points:w.points});
 });res.json({ok:true});
}));
app.use((err,req,res,_next)=>{
 if(err.code==='22P02')return res.status(400).json({error:'Invalid identifier'});
 const status=err.status||500;
 if(status>=500)console.error(err);
 res.status(status).json({error:status>=500?'Server error':err.message});
});
const port=Number(process.env.PORT||3000);
const server=app.listen(port,()=>console.log(`NovaLive API listening on ${port}`));
const stop=()=>server.close(()=>db.end().then(()=>process.exit(0)));
process.on('SIGTERM',stop);process.on('SIGINT',stop);
