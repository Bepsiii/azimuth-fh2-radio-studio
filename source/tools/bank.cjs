// Keep original event tables, but stream PCM rather than retaining every song in memory.
const fs=require('node:fs'),path=require('node:path'),crypto=require('node:crypto');
function read(fd,at,length){const b=Buffer.alloc(length);let n=0;while(n<length){const done=fs.readSync(fd,b,n,length-n,at+n);if(!done)throw Error('Truncated audio bank');n+=done;}return b;}
function pcm(file){const fd=fs.openSync(file,'r');try{const size=fs.fstatSync(fd).size,root=read(fd,0,12);if(root.toString('ascii',0,4)!=='RIFF'||root.toString('ascii',8)!=='WAVE')throw Error('Expected RIFF WAV');let format,data;for(let p=12;p+8<=size;){const h=read(fd,p,8),n=h.readUInt32LE(4);if(p+8+n>size)throw Error('Truncated WAV');if(h.toString('ascii',0,4)==='fmt ')format=read(fd,p+8,Math.min(n,40));if(h.toString('ascii',0,4)==='data')data={file,offset:p+8,bytes:n};p+=8+n+(n&1);}if(!format||format.length<16||format.readUInt16LE(0)!==1||format.readUInt16LE(2)!==2||format.readUInt32LE(4)!==48000||format.readUInt16LE(14)!==16||!data||data.bytes%4)throw Error('Expected 48 kHz stereo PCM16');const hash=crypto.createHash('sha256'),buffer=Buffer.alloc(1024*1024);for(let n=0;n<data.bytes;){const got=fs.readSync(fd,buffer,0,Math.min(buffer.length,data.bytes-n),data.offset+n);if(!got)throw Error('Truncated PCM');hash.update(buffer.subarray(0,got));n+=got;}data.hash=hash.digest('hex');return data;}finally{fs.closeSync(fd);}}
module.exports=function bank(input,output,items,work,silentFrames=4800){
 const fd=fs.openSync(input,'r');let prefix,header,names,count,snd,sndh,start;
 try{
  const size=fs.fstatSync(fd).size,root=read(fd,0,12);if(root.toString('ascii',0,4)!=='RIFF'||root.toString('ascii',8)!=='FEV ')throw Error('Unsupported FMOD event bank');
  for(let p=12;p+8<=size;){const h=read(fd,p,8),id=h.toString('ascii',0,4),n=h.readUInt32LE(4);if(p+8+n>size)throw Error('Invalid bank bounds');if(id==='LIST'){for(let q=p+12;q+8<=p+8+n;){const sub=read(fd,q,8),length=sub.readUInt32LE(4);if(q+8+length>p+8+n)throw Error('Invalid LIST chunk');if(sub.toString('ascii',0,4)==='SNDH')sndh=q+8;q+=8+length+(length&1);}}if(id==='SND '){snd=p;break;}p+=8+n+(n&1);}
  if(sndh===undefined||snd===undefined)throw Error('Missing bank chunks');start=read(fd,sndh,12).readUInt32LE(4);header=read(fd,start,60);if(header.toString('ascii',0,4)!=='FSB5')throw Error('Expected FSB5');count=header.readUInt32LE(8);if(count<1||count>4096)throw Error('Unsupported subsound count');const oldHeader=header.readUInt32LE(12),nameSize=header.readUInt32LE(16);if(nameSize>1024*1024||start>10*1024*1024)throw Error('Unsupported bank tables');names=read(fd,start+60+oldHeader,nameSize);prefix=read(fd,0,start);
 }finally{fs.closeSync(fd);}
 if(items&&(items.length<1||items.length>count))throw Error('Track count exceeds station capacity');
 const nameSize=names.length+((32-(60+count*8+names.length)%32)%32),nameTable=Buffer.alloc(nameSize);names.copy(nameTable);
 const headers=Buffer.alloc(count*8),refs=[];let size=0;
 for(let i=0;i<count;i++){
  const item=items&&items[i],ref=item?pcm(path.join(work,item.wav)):{bytes:silentFrames*4};const frames=ref.bytes/4;
  if(!Number.isInteger(frames)||frames>=2**30||size/32>=2**27)throw Error('Audio exceeds FSB5 limits');
  const bits=(BigInt(frames)<<34n)|(BigInt(size/32)<<7n)|(1n<<5n)|(9n<<1n);headers.writeBigUInt64LE(bits,i*8);refs.push(ref);size+=ref.bytes+((32-ref.bytes%32)%32);
  if(item){const p=names.readUInt32LE(i*4),end=names.indexOf(0,p);if(p<count*4||end<p)throw Error('Invalid bank name table');Object.assign(item,{sound_name:names.toString('utf8',p,end),subsound:i+1,frames,pcm_sha256:ref.hash});}
 }
 const fsbSize=60+headers.length+nameSize+size,total=start+fsbSize;if(total>=2**32)throw Error('Bank exceeds RIFF size limit');
 header.writeUInt32LE(count*8,12);header.writeUInt32LE(nameSize,16);header.writeUInt32LE(size,20);header.writeUInt32LE(2,24);prefix.writeUInt32LE(total-8,4);prefix.writeUInt32LE(total-snd-8,snd+4);prefix.writeUInt32LE(fsbSize,sndh+8);
 const dest=fs.openSync(output,'w'),buffer=Buffer.alloc(1024*1024);try{for(const b of [prefix,header,headers,nameTable])fs.writeSync(dest,b);for(const ref of refs){if(ref.file){const source=fs.openSync(ref.file,'r');try{for(let n=0;n<ref.bytes;){const got=fs.readSync(source,buffer,0,Math.min(buffer.length,ref.bytes-n),ref.offset+n);if(!got)throw Error('Truncated PCM');fs.writeSync(dest,buffer,0,got);n+=got;}}finally{fs.closeSync(source);}}else{buffer.fill(0);for(let n=0;n<ref.bytes;){const amount=Math.min(buffer.length,ref.bytes-n);fs.writeSync(dest,buffer,0,amount);n+=amount;}}const pad=(32-ref.bytes%32)%32;if(pad)fs.writeSync(dest,Buffer.alloc(pad));}}finally{fs.closeSync(dest);}
 console.log(path.basename(output),count,'subsounds',total,'bytes');
};
