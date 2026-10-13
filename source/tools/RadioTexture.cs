using System;
using System.IO;
public static class RadioTexture {
    public static void Build(string templatePath,string ddsPath,string mapPath,string outputPath) {
        byte[] original=File.ReadAllBytes(templatePath),dds=File.ReadAllBytes(ddsPath),map=File.ReadAllBytes(mapPath);
        if(original.Length!=32851 || BitConverter.ToUInt32(original,8)!=83 || BitConverter.ToUInt16(original,64)!=196 || (BitConverter.ToUInt16(original,66)!=104 && BitConverter.ToUInt16(original,66)!=96) || (BitConverter.ToUInt32(original,79)&2047)!=302) throw new InvalidDataException("Unsupported FH2 icon layout");
        int height=BitConverter.ToUInt16(original,66),blocks=49*(height/4);
        if(dds.Length!=148+blocks*16 || BitConverter.ToUInt32(dds,0)!=0x20534444 || BitConverter.ToUInt32(dds,128)!=98 || BitConverter.ToUInt32(dds,16)!=196 || BitConverter.ToUInt32(dds,12)!=height || BitConverter.ToUInt32(dds,28)!=1) throw new InvalidDataException("Expected 196x104 BC7_UNORM DDS with one mip");
        if(map.Length!=2548)throw new InvalidDataException("Invalid layout map");
        byte[] output=new byte[32851];Buffer.BlockCopy(original,0,output,0,83);bool[] used=new bool[2048];
        for(int i=0;i<blocks;i++){int block=BitConverter.ToUInt16(map,i*2);if(block>=2048||used[block])throw new InvalidDataException("Invalid block address");used[block]=true;Buffer.BlockCopy(dds,148+i*16,output,83+block*16,16);}
        File.WriteAllBytes(outputPath,output);
    }
}
