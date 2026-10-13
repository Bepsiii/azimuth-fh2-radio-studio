using System;
using System.IO;
using System.Text;
using System.Collections.Generic;
using System.IO.Compression;

namespace FH2Radio {
    // FH2 uses standard ZIP payloads plus 0x1123 extra fields containing each
    // payload's absolute byte offset. Keep those fields correct in both headers.
    public static class ForzaZip {
        static ushort U16(byte[] b,int o) {return BitConverter.ToUInt16(b,o);}
        static uint U32(byte[] b,int o) {return BitConverter.ToUInt32(b,o);}
        static void W16(byte[] b,int o,int v) {Array.Copy(BitConverter.GetBytes((ushort)v),0,b,o,2);}
        static void W32(byte[] b,int o,uint v) {Array.Copy(BitConverter.GetBytes(v),0,b,o,4);}
        static byte[] Slice(byte[] b,int o,int n) {var a=new byte[n];Array.Copy(b,o,a,0,n);return a;}
        static uint Crc(byte[] b) {uint c=0xffffffff;foreach(byte x in b){c^=x;for(int j=0;j<8;j++)c=(c>>1)^((c&1)!=0?0xedb88320:0);}return ~c;}
        static byte[] Extras(byte[] b,uint offset) {
            var result=(byte[])b.Clone();bool found=false;
            for(int p=0;p<b.Length;) {if(p+4>b.Length)throw new InvalidDataException("ZIP extra field bounds");int n=U16(b,p+2);if(p+4+n>b.Length)throw new InvalidDataException("ZIP extra field bounds");if(U16(b,p)==1)throw new InvalidDataException("ZIP64 not supported");if(U16(b,p)==0x1123){if(n!=4)throw new InvalidDataException("Unknown Forza offset format");W32(result,p+4,offset);found=true;}p+=4+n;}
            if(found)return result;
            Array.Resize(ref result,result.Length+8);int q=result.Length-8;W16(result,q,0x1123);W16(result,q+2,4);W32(result,q+4,offset);return result;
        }
        sealed class Entry {
            public byte[] Central,Local,Name,LocalName,Extra,LocalExtra,Comment,Data;
            public uint OldOffset,NewOffset;
        }
        public static void Replace(string filename,string entryName,byte[] replacement) {
            byte[] source=File.ReadAllBytes(filename);int end=-1;
            for(int p=source.Length-22;p>=Math.Max(0,source.Length-65557);p--)if(U32(source,p)==0x06054b50&&p+22+U16(source,p+20)==source.Length){end=p;break;}
            if(end<0||U16(source,end+4)!=0||U16(source,end+6)!=0||U16(source,end+8)!=U16(source,end+10))throw new InvalidDataException("Unsupported ZIP layout");
            int count=U16(source,end+10),cursor=checked((int)U32(source,end+16)),changed=0;
            var entries=new List<Entry>();
            for(int i=0;i<count;i++) {
                if(U32(source,cursor)!=0x02014b50)throw new InvalidDataException("ZIP central header");
                int nl=U16(source,cursor+28),el=U16(source,cursor+30),cl=U16(source,cursor+32);
                var e=new Entry();e.Central=Slice(source,cursor,46);e.Name=Slice(source,cursor+46,nl);e.Extra=Slice(source,cursor+46+nl,el);e.Comment=Slice(source,cursor+46+nl+el,cl);e.OldOffset=U32(source,cursor+42);
                int local=checked((int)e.OldOffset);if(U32(source,local)!=0x04034b50)throw new InvalidDataException("ZIP local header");
                int lnl=U16(source,local+26),lel=U16(source,local+28);e.Local=Slice(source,local,30);e.LocalName=Slice(source,local+30,lnl);e.LocalExtra=Slice(source,local+30+lnl,lel);
                e.Data=Slice(source,local+30+lnl+lel,checked((int)U32(e.Central,20)));
                if(Encoding.UTF8.GetString(e.Name)==entryName) {
                    changed++;using(var memory=new MemoryStream()){using(var deflate=new DeflateStream(memory,CompressionLevel.Optimal,true)){deflate.Write(replacement,0,replacement.Length);}e.Data=memory.ToArray();}
                    uint crc=Crc(replacement);W16(e.Central,10,8);W32(e.Central,16,crc);W32(e.Central,20,(uint)e.Data.Length);W32(e.Central,24,(uint)replacement.Length);
                }
                // Write explicit CRC/sizes; do not retain trailing data descriptors.
                int flags=U16(e.Central,8)&~8;if((flags&1)!=0)throw new InvalidDataException("Encrypted ZIP unsupported");W16(e.Central,8,flags);W16(e.Local,6,flags);W16(e.Local,8,U16(e.Central,10));W32(e.Local,14,U32(e.Central,16));W32(e.Local,18,U32(e.Central,20));W32(e.Local,22,U32(e.Central,24));
                entries.Add(e);cursor+=46+nl+el+cl;
            }
            if(changed!=1)throw new InvalidDataException("Expected one ZIP entry: "+entryName);
            using(var output=new MemoryStream()) {
                var physical=new List<Entry>(entries);physical.Sort((a,b)=>a.OldOffset.CompareTo(b.OldOffset));
                foreach(var e in physical) {
                    e.NewOffset=checked((uint)output.Position);byte[] extra=Extras(e.LocalExtra,0);
                    uint dataOffset=checked((uint)(output.Position+30+e.LocalName.Length+extra.Length));extra=Extras(extra,dataOffset);e.Extra=Extras(e.Extra,dataOffset);
                    W16(e.Local,28,extra.Length);output.Write(e.Local,0,e.Local.Length);output.Write(e.LocalName,0,e.LocalName.Length);output.Write(extra,0,extra.Length);output.Write(e.Data,0,e.Data.Length);
                }
                uint centralOffset=checked((uint)output.Position);
                foreach(var e in entries){W16(e.Central,30,e.Extra.Length);W32(e.Central,42,e.NewOffset);output.Write(e.Central,0,46);output.Write(e.Name,0,e.Name.Length);output.Write(e.Extra,0,e.Extra.Length);output.Write(e.Comment,0,e.Comment.Length);}
                uint centralSize=checked((uint)output.Position-centralOffset);byte[] tail=Slice(source,end,source.Length-end);W32(tail,12,centralSize);W32(tail,16,centralOffset);output.Write(tail,0,tail.Length);
                File.WriteAllBytes(filename,output.ToArray());
            }
        }
    }
}
