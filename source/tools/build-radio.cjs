// FH2 custom radio builder. Preserves the game's event IDs and bank wrappers.
const fs = require('node:fs');
const path = require('node:path');
const crypto = require('node:crypto');
const work=path.resolve(process.argv[3]), output=path.resolve(process.argv[4]);
const media = process.argv[2];
const slot=Number(process.argv[5]), id=String(slot).padStart(2,'0');
if(!Number.isInteger(slot)||slot<1||slot>7)throw Error('Unsupported station');
const stationPattern=new RegExp(`<RadioStation\\b[^>]*Number="${slot}"[^>]*>[\\s\\S]*?</RadioStation>`,'g');
if (!media) throw Error('Pass the original Mount/media directory');
const out = path.join(output, 'media', 'audio');
fs.mkdirSync(path.join(out, 'fmodanthem', 'durango'), {recursive:true});
const tracks = JSON.parse(fs.readFileSync(path.join(work,'tracks.json'),'utf8'));
const constructBank=require('./bank.cjs');
const bank=(input,output,items,silentFrames)=>constructBank(input,output,items,work,silentFrames);
const bankDir=path.join(media,'audio','fmodanthem','durango');
bank(path.join(bankDir,`HZ2_MX_Radio_${id}_Tracks.bank`),path.join(out,'fmodanthem','durango',`HZ2_MX_Radio_${id}_Tracks.bank`),tracks);
for(const name of fs.readdirSync(bankDir).filter(n=>new RegExp(`^HZ2_MX_Radio_${id}_(DJ|Stingers)_.*\\.bank$`).test(n)))bank(path.join(bankDir,name),path.join(out,'fmodanthem','durango',name),undefined,name.includes('_Stingers_')?120000:4800);
const escape=s=>s.replaceAll('&','&amp;').replaceAll('"','&quot;').replaceAll('<','&lt;').replaceAll('>','&gt;');
const music=tracks.map(t=>{const length=Math.floor(t.frames/48),end=length-100;return `        <Entry EventName="/Master/Radio/Track" SoundName="${t.sound_name}" SampleLength="${length}" DisplayName="${escape(t.title)}" Artist="${escape(t.artist)}" TrackStart="0" DJDrop="0" TrackDrop="0" TrackBreakDown="${Math.floor(end*0.75)}" StingerStart="${end-2000}" DJStart="${end-1000}" End="${end}"/>`;}).join('\r\n');
for(const name of fs.readdirSync(path.join(media,'audio')).filter(n=>/^RadioInfo_.*\.xml$/.test(n))) {
  const xml=fs.readFileSync(path.join(media,'audio',name),'utf8');let matches=0;
  const patched=xml.replace(stationPattern,station=>{
    matches++;let s=station.replace(/RecentlyPlayedListSize="-?\d+"/,'RecentlyPlayedListSize="'+(tracks.length===1?0:Math.min(8,Math.max(1,Math.floor((tracks.length-1)/2))))+'"'); // Preserve the game's internal station identifier.
    s=s.replace(/(<Playlist Type="(?:FreeroamTracks|EventTracks)"[^>]*>)[\s\S]*?(<\/Playlist>)/g,`$1\r\n${music}\r\n      $2`);
    s=s.replace(/(<Playlist Type="(DJ|Stingers|ShortStingers)"[^>]*>)([\s\S]*?)(<\/Playlist>)/g,(_,a,kind,body,z)=>a+body.replace(/SampleLength="\d+"/g,kind==='DJ'?'SampleLength="100"':'SampleLength="2500"').replace(/StartNextTrack="\d+"/g,'StartNextTrack="2000"').replace(/End="\d+"/g,kind==='DJ'?'End="99"':'End="2499"')+z);return s;
  });if(matches!==1)throw Error('Expected selected station in '+name);fs.writeFileSync(path.join(output,'patches',name.replace('RadioInfo_','RadioStation_')),patched.match(stationPattern)[0]);
}
fs.writeFileSync(path.join(output,'tracks.json'),JSON.stringify(tracks,null,2)+'\n');
