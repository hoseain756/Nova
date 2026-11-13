import {readFileSync} from 'node:fs';
import {randomUUID} from 'node:crypto';
// Only the public application URL/key are used. No Auth user or chat message
// is created. Joining starts Supabase's managed Realtime partition window.
const main=readFileSync(new URL('../../lib/core/auth/nova_backend_config.dart',import.meta.url),'utf8');
const base=main.match(/defaultValue: '(https:\/\/[^']+\.supabase\.co)'/)?.[1];
const key=main.match(/defaultValue: '(sb_publishable_[^']+)'/)?.[1];
if(!base||!key)throw new Error('Public application configuration not found');
const url=new URL('/realtime/v1/websocket',base);url.protocol='wss:';
url.searchParams.set('apikey',key);url.searchParams.set('vsn','1.0.0');
const topic=`realtime:nova-party-connect-smoke:${randomUUID()}`;
const socket=new WebSocket(url);
await new Promise((resolve,reject)=>{
  const timer=setTimeout(()=>{socket.close();reject(new Error('Realtime join timed out'));},20000);
  socket.addEventListener('open',()=>socket.send(JSON.stringify({topic,event:'phx_join',ref:'1',payload:{config:{broadcast:{self:false},presence:{key:''},postgres_changes:[],private:false}}})));
  socket.addEventListener('message',({data})=>{
    const message=JSON.parse(data);
    if(message.event==='phx_reply'&&message.ref==='1'){
      clearTimeout(timer);
      if(message.payload?.status==='ok'){console.log(JSON.stringify({websocketConnected:true,publicProbeJoined:true,noUserCreated:true,noMessageSent:true}));socket.close();resolve();}
      else{socket.close();reject(new Error('Realtime join rejected'));}
    }
  });
  socket.addEventListener('error',()=>{clearTimeout(timer);reject(new Error('Realtime transport error'));});
});
