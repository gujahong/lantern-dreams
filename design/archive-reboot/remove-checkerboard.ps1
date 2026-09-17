param([string]$AssetFolder = $PSScriptRoot)
$ErrorActionPreference = 'Stop'
Add-Type -AssemblyName System.Drawing
Add-Type -ReferencedAssemblies System.Drawing -TypeDefinition @'
using System;
using System.Drawing;
using System.Drawing.Imaging;
using System.Runtime.InteropServices;
public static class CheckerCleanup {
 public static string Run(string source, string output, string background, string preview, string contrast) {
  using(var input=new Bitmap(source)) using(var bmp=new Bitmap(input.Width,input.Height,PixelFormat.Format32bppArgb)) {
   using(var g=Graphics.FromImage(bmp)) g.DrawImageUnscaled(input,0,0);
   int w=bmp.Width,h=bmp.Height,n=w*h;
   var bd=bmp.LockBits(new Rectangle(0,0,w,h),ImageLockMode.ReadWrite,PixelFormat.Format32bppArgb);
   byte[] bytes=new byte[bd.Stride*h];Marshal.Copy(bd.Scan0,bytes,0,bytes.Length);
   bool[] candidate=new bool[n],seen=new bool[n];int[] queue=new int[n];int removed=0;
   for(int y=0;y<h;y++) for(int x=0;x<w;x++) {
    int k=y*bd.Stride+x*4;int b=bytes[k],gg=bytes[k+1],r=bytes[k+2];
    int min=Math.Min(r,Math.Min(gg,b)), max=Math.Max(r,Math.Max(gg,b));
    candidate[y*w+x]=min>=138 && max-min<=34 && b>=r-9 && b>=gg-9;
   }
   for(int start=0;start<n;start++) {
    if(!candidate[start]||seen[start])continue;
    int head=0,tail=1;queue[0]=start;seen[start]=true;
    while(head<tail) {
     int p=queue[head++],x=p%w,y=p/w;
     if(x>0)Visit(p-1,candidate,seen,queue,ref tail);
     if(x<w-1)Visit(p+1,candidate,seen,queue,ref tail);
     if(y>0)Visit(p-w,candidate,seen,queue,ref tail);
     if(y<h-1)Visit(p+w,candidate,seen,queue,ref tail);
    }
    // Preserve isolated light glints on the subject. Large neutral light regions are the baked backdrop.
    if(tail<512)continue;
    for(int j=0;j<tail;j++){int p=queue[j];bytes[(p/w)*bd.Stride+(p%w)*4+3]=0;removed++;}
   }
   // Remove neutral checker antialias fringes only immediately adjacent to the extracted backdrop.
   byte[] clean=(byte[])bytes.Clone();
   for(int y=1;y<h-1;y++)for(int x=1;x<w-1;x++){
    int k=y*bd.Stride+x*4;if(bytes[k+3]==0)continue;
    int b=bytes[k],gg=bytes[k+1],r=bytes[k+2];
    int min=Math.Min(r,Math.Min(gg,b)),max=Math.Max(r,Math.Max(gg,b));
    if(min<70||max-min>30||b<r-5)continue;
    if(bytes[k-4+3]==0||bytes[k+4+3]==0||bytes[k-bd.Stride+3]==0||bytes[k+bd.Stride+3]==0){clean[k+3]=0;removed++;}
   }
   Marshal.Copy(clean,0,bd.Scan0,clean.Length);bmp.UnlockBits(bd);bmp.Save(output,ImageFormat.Png);
   using(var bg=new Bitmap(background)) using(var result=new Bitmap(w,h)) {
    using(var g=Graphics.FromImage(result)){g.DrawImageUnscaled(bg,0,0);g.DrawImageUnscaled(bmp,0,0);}
    result.Save(preview,ImageFormat.Png);
   }
   using(var result=new Bitmap(w,h)) {
    using(var g=Graphics.FromImage(result)){g.Clear(Color.FromArgb(40,55,70));g.DrawImageUnscaled(bmp,0,0);}
    result.Save(contrast,ImageFormat.Png);
   }
   return String.Format("{0}x{1}; transparent pixels: {2}/{3}; retained RGB unchanged",w,h,removed,n);
  }
 }
 static void Visit(int p,bool[] c,bool[] seen,int[] q,ref int tail){if(c[p]&&!seen[p]){seen[p]=true;q[tail++]=p;}}
}
'@
[CheckerCleanup]::Run(
 (Join-Path $AssetFolder 'watcher-foreground-draft.png'),
 (Join-Path $AssetFolder 'watcher-foreground.png'),
 (Join-Path $AssetFolder 'battle-background-v1.png'),
 (Join-Path $AssetFolder 'battle-layered-preview.png'),
 (Join-Path $AssetFolder 'watcher-alpha-check.png'))
