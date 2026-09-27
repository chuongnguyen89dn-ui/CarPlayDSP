#pragma once
#include <cmath>
class CPBiquad {
public:
    void setPeaking(double sampleRate,double frequency,double q,double gainDB);
    float process(float x);
    void reset();
private:
    double b0=1,b1=0,b2=0,a1=0,a2=0,z1=0,z2=0;
};
