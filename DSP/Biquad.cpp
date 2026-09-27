#include "Biquad.hpp"
void CPBiquad::setPeaking(double fs,double f,double q,double gainDB){
    const double A=std::pow(10.0,gainDB/40.0);
    const double w=2.0*M_PI*f/fs, alpha=std::sin(w)/(2.0*q), c=std::cos(w);
    double B0=1+alpha*A,B1=-2*c,B2=1-alpha*A,A0=1+alpha/A,A1=-2*c,A2=1-alpha/A;
    b0=B0/A0;b1=B1/A0;b2=B2/A0;a1=A1/A0;a2=A2/A0;
}
float CPBiquad::process(float x){ double y=b0*x+z1; z1=b1*x-a1*y+z2; z2=b2*x-a2*y; return (float)y; }
void CPBiquad::reset(){z1=z2=0;}
