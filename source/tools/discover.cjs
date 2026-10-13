const fs=require('node:fs'),path=require('node:path');
let mount=path.resolve(process.argv[2]);if(fs.existsSync(path.join(mount,'Mount/media/audio')))mount=path.join(mount,'Mount');
const xml=fs.readFileSync(path.join(mount,'media/audio/RadioInfo_EN.xml'),'utf8');
const stations=require('./stations.json').map(s=>{
 const bank=path.join(mount,'media/audio/fmodanthem/durango',`HZ2_MX_Radio_${String(s.slot).padStart(2,'0')}_Tracks.bank`);
 const present=new RegExp(`<RadioStation\\b[^>]*Number="${s.slot}"[^>]*>`).test(xml);
 let maxTracks=0;
 if(present&&fs.existsSync(bank)){const fd=fs.openSync(bank,'r');let b;try{b=Buffer.alloc(Math.min(fs.fstatSync(fd).size,10*1024*1024));fs.readSync(fd,b,0,b.length,0);}finally{fs.closeSync(fd);}const p=b.indexOf('FSB5');if(p>=0&&p+60<=b.length)maxTracks=b.readUInt32LE(p+8);}
 return {...s,maxTracks,available:maxTracks>0&&maxTracks<=100};
});process.stdout.write(JSON.stringify({mount,stations}));
