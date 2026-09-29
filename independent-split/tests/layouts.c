#define CPS_PORTABLE_GEOMETRY_TEST
#include "../CPSLayouts.h"
#include <assert.h>
#include <stdio.h>
static double area(CGRect r){return r.size.width*r.size.height;}
static double overlap(CGRect a,CGRect b){return fmax(0,fmin(a.origin.x+a.size.width,b.origin.x+b.size.width)-fmax(a.origin.x,b.origin.x))*fmax(0,fmin(a.origin.y+a.size.height,b.origin.y+b.size.height)-fmax(a.origin.y,b.origin.y));}
int main(void){
 double ratios[]={0,.001,.2,1./3,.5,.8,.999,1,NAN};
 CGRect screens[]={{{0,0},{427,240}},{{0,0},{800,480}},{{45,0},{382,240}},{{13,21},{1024,600}}};
 int checks=0;
 for(int k=1;k<=8;k++)for(int s=0;s<4;s++)for(int a=0;a<9;a++)for(int b=0;b<9;b++){
  CGRect r=screens[s];CPSFrames f=CPSFramesMake(r,k,ratios[a],ratios[b],-1);double total=0;assert(f.count==(k==1?1:k<4?2:3));
  for(int i=0;i<f.count;i++){CGRect p=f.panes[i];assert(isfinite(area(p))&&p.size.width>=0&&p.size.height>=0);assert(p.origin.x>=r.origin.x-1e-7&&p.origin.y>=r.origin.y-1e-7);assert(p.origin.x+p.size.width<=r.origin.x+r.size.width+1e-7);assert(p.origin.y+p.size.height<=r.origin.y+r.size.height+1e-7);total+=area(p);for(int j=0;j<i;j++)assert(overlap(p,f.panes[j])<1e-6);}
  assert(fabs(total-area(r))<1e-6);
  for(int i=0;i<f.count;i++){CPSFrames m=CPSFramesMake(r,k,ratios[a],ratios[b],i);assert(fabs(area(m.panes[i])-area(r))<1e-6);assert(m.boundaryCount==0);for(int j=0;j<f.count;j++)if(j!=i)assert(area(m.panes[j])==0);}
  checks++;
 }
 assert(CPSFramesMake(CGRectMake(0,0,0,240),2,.5,.5,-1).count==0);
 assert(CPSFramesMake(CGRectMake(0,0,NAN,240),2,.5,.5,-1).count==0);
 assert(CPSFramesMake(CGRectMake(0,0,427,240),2,0,.5,-1).panes[1].size.width==427);
 assert(CPSFramesMake(CGRectMake(0,0,427,240),2,1,.5,-1).panes[0].size.width==427);
 printf("%d layout cases: full coverage, no overlap, valid bounds, edge ratios and every maximized pane verified.\n",checks);
}
