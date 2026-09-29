#pragma once
#include "CPSGeometryTypes.h"
#include <math.h>
// Independent geometry. IDs correspond to the eight observed reference shapes.
typedef struct { CGRect panes[3]; CGRect boundaries[2]; bool vertical[2]; int count, boundaryCount; } CPSFrames;
static inline double CPSClamp(double v,double lo,double hi) { return isfinite(v)?fmax(lo,fmin(hi,v)):(lo+hi)/2; }
static inline CPSFrames CPSFramesMake(CGRect r,int kind,double a,double b,int maximized) {
    CPSFrames o={0}; double x=r.origin.x,y=r.origin.y,w=r.size.width,h=r.size.height;
    if(!isfinite(w)||!isfinite(h)||w<=0||h<=0)return o;
    kind=kind<1||kind>8?2:kind; o.count=kind==1?1:(kind<=3?2:3);
    if(maximized>=0&&maximized<o.count){o.panes[maximized]=r;return o;}
    a=CPSClamp(a,0,1);b=CPSClamp(b,0,1);
    if(kind==1){o.panes[0]=r;return o;}
    o.boundaryCount=kind<=3?1:2;
    if(kind==2 || kind==4){
        double cuts[4]={0,a,kind==4?fmax(a,b):1,1};
        for(int i=0;i<o.count;i++)o.panes[i]=CGRectMake(x+w*cuts[i],y,w*(cuts[i+1]-cuts[i]),h);
        for(int i=0;i<o.boundaryCount;i++){o.boundaries[i]=CGRectMake(x+w*cuts[i+1],y,0,h);o.vertical[i]=true;}
    } else if(kind==3){
        o.panes[0]=CGRectMake(x,y,w,h*a);o.panes[1]=CGRectMake(x,y+h*a,w,h*(1-a));
        o.boundaries[0]=CGRectMake(x,y+h*a,w,0);
    } else if(kind==5||kind==6){
        double l=w*a,rr=w-l,t=h*b;
        o.vertical[0]=true;o.boundaries[0]=CGRectMake(x+l,y,0,h);
        if(kind==5){o.panes[0]=CGRectMake(x,y,l,h);o.panes[1]=CGRectMake(x+l,y,rr,t);o.panes[2]=CGRectMake(x+l,y+t,rr,h-t);o.boundaries[1]=CGRectMake(x+l,y+t,rr,0);}
        else {o.panes[0]=CGRectMake(x,y,l,t);o.panes[1]=CGRectMake(x,y+t,l,h-t);o.panes[2]=CGRectMake(x+l,y,rr,h);o.boundaries[1]=CGRectMake(x,y+t,l,0);}
    } else {
        double t=h*a,l=w*b;
        o.boundaries[0]=CGRectMake(x,y+t,w,0);o.vertical[1]=true;
        if(kind==7){o.panes[0]=CGRectMake(x,y,w,t);o.panes[1]=CGRectMake(x,y+t,l,h-t);o.panes[2]=CGRectMake(x+l,y+t,w-l,h-t);o.boundaries[1]=CGRectMake(x+l,y+t,0,h-t);}
        else {o.panes[0]=CGRectMake(x,y,l,t);o.panes[1]=CGRectMake(x+l,y,w-l,t);o.panes[2]=CGRectMake(x,y+t,w,h-t);o.boundaries[1]=CGRectMake(x+l,y,0,t);}
    }
    return o;
}
