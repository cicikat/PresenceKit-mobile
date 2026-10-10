#version 460 core
#include <flutter/runtime_effect.glsl>
uniform vec2 uSize;
uniform float uTime;
uniform float uMode;
uniform float uScale;
uniform float uWarp;
uniform float uSeed;
uniform float uDark;
uniform vec3 uViolet;
uniform vec3 uMagenta;
uniform vec3 uPeach;
uniform vec2 uOrigin;
uniform vec2 uPanel;
uniform float uRadius;
uniform float uThickness;
uniform float uReflection;
out vec4 fragColor;

mat2 rot(float a){return mat2(cos(a),-sin(a),sin(a),cos(a));}
float ellipse(vec2 p,vec2 r){return (length(p/r)-1.)*min(r.x,r.y);}
float hash3(vec3 p){p=fract(p*.1031);p+=dot(p,p.yzx+33.33);return fract((p.x+p.y)*p.z);}
float noise3(vec3 p){vec3 i=floor(p),f=fract(p);f=f*f*f*(f*(f*6.-15.)+10.);return mix(mix(mix(hash3(i),hash3(i+vec3(1,0,0)),f.x),mix(hash3(i+vec3(0,1,0)),hash3(i+vec3(1,1,0)),f.x),f.y),mix(mix(hash3(i+vec3(0,0,1)),hash3(i+vec3(1,0,1)),f.x),mix(hash3(i+vec3(0,1,1)),hash3(i+vec3(1,1,1)),f.x),f.y),f.z)*2.-1.;}
float fbm(vec3 p){return .68*noise3(p)+.32*noise3(p*2.03+vec3(17.1,31.7,7.3));}
vec3 baseColor(){return mix(vec3(.91,.94,.99),vec3(.003,.002,.012),uDark);}
vec3 background(vec2 coord){
  vec2 uv=coord/uSize;
  uv=(uv-.5)/uScale+.5;
  float t=uTime;
  if(uMode<.5){
    vec2 p=uv*vec2(430.,860.);
    p+=uWarp/1.15*vec2(22.*sin(p.y*.008+t*.9)+9.*sin(p.y*.019-t*.6),18.*sin(p.x*.008+t*.7)+8.*sin(p.x*.024-t*.5));
    vec3 c=baseColor();
    vec2 q=rot(-.36+.14*sin(t*.6))*(p-vec2(175.+18.*sin(t),255.+20.*sin(t*.65)));
    float ring=ellipse(q,vec2(96.+9.*sin(t*.8),140.+14.*sin(t*.55)));
    float band=exp(-pow(ring/22.,2.));
    vec3 ribbon1=mix(uViolet,uMagenta,smoothstep(-70.,70.,q.y));
    c=mix(c,ribbon1,band*.85);
    c+=uViolet*exp(-pow(ring/42.,2.))*.12*uDark;
    float cx=251.+(53.+14.*sin(t*.45))*sin((p.y-200.)*(.010+.0015*sin(t*.35))+t*.6);
    float dx=p.x-cx;
    float gate=smoothstep(100.,200.,p.y)*(1.-smoothstep(680.,810.,p.y));
    float shape=exp(-pow(abs(dx)/43.,4.))*gate;
    float envelope=exp(-pow(dx/72.,2.))*gate;
    float pink=exp(-pow((dx+28.)/25.,2.));
    c=mix(c,uMagenta,envelope*.45);
    c=mix(c,mix(uPeach,uMagenta,pink*.78),shape*.92);
    vec2 q2=rot(.27+.14*sin(t*.55))*(p-vec2(160.+12.*sin(t*.7),607.+18.*cos(t*.6)));
    float lowerRing=exp(-pow(ellipse(q2,vec2(75.,115.))/27.,2.))*.60;
    c=mix(c,mix(uMagenta,uPeach,smoothstep(-30.,70.,q2.x)),lowerRing);
    float vignette=1.-smoothstep(165.,250.,abs(p.x-215.));
    return clamp(mix(baseColor(),c,vignette),0.,1.);
  }
  vec2 p=(uv-.5)*vec2(2.,4.);
  vec3 domain=vec3(p*.86+vec2(uSeed,uSeed*.71),t*.21);
  vec2 q=vec2(fbm(domain),fbm(domain+vec3(5.2,1.3,2.1)));
  vec2 r=vec2(fbm(domain+vec3(q*uWarp+vec2(1.7,9.2),1.3)),fbm(domain+vec3(q*uWarp+vec2(8.3,2.8),4.7)));
  float field=fbm(domain+vec3(r*uWarp,2.8))+.18*r.y;
  float ridge=exp(-pow((field-.04)/.19,2.));
  float mass=smoothstep(.25,.88,ridge);
  float lighting=.75+.20*q.x;
  float warmth=smoothstep(-.08,.35,field+.26*q.y);
  vec3 liquid=mix(uViolet,uMagenta,smoothstep(.18,.75,ridge));
  liquid=mix(liquid,uPeach,warmth*.92);
  return clamp(mix(baseColor(),liquid*mix(1.,lighting,uDark),mass),0.,1.);
}
float box(vec2 p,vec2 b,float r){vec2 q=abs(p)-b+r;return length(max(q,0.))+min(max(q.x,q.y),0.)-r;}
void main(){
  vec2 local=FlutterFragCoord().xy;
  if(uPanel.x<1.){fragColor=vec4(background(local),1.);return;}
  vec2 halfSize=uPanel*.5,p=local-halfSize;
  float radius=min(uRadius,min(halfSize.x,halfSize.y));
  float d=box(p,halfSize,radius);
  vec2 g=normalize(vec2(box(p+vec2(.7,0.),halfSize,radius)-box(p-vec2(.7,0.),halfSize,radius),box(p+vec2(0.,.7),halfSize,radius)-box(p-vec2(0.,.7),halfSize,radius))+1e-6);
  float bw=min(23.,min(halfSize.x,halfSize.y)*.8);
  float a=clamp(-d/bw,0.,1.),ct=1.-a,h=sqrt(max(1.-ct*ct,.001));
  vec3 n=normalize(vec3(-g*uThickness/bw*ct/max(h,.1)+p/max(halfSize,vec2(1.))*.08,1.));
  float distance=uThickness*mix(.4,1.,h)*2.7;
  vec3 rr=refract(vec3(0.,0.,-1.),n,1./1.442),rg=refract(vec3(0.,0.,-1.),n,1./1.46),rb=refract(vec3(0.,0.,-1.),n,1./1.478);
  vec2 pos=local+uOrigin;
  vec3 transmitted=vec3(background(pos+rr.xy/max(-rr.z,.2)*distance).r,background(pos+rg.xy/max(-rg.z,.2)*distance).g,background(pos+rb.xy/max(-rb.z,.2)*distance).b);
  float rim=exp(-max(-d,0.)/9.);
  vec3 glass=mix(mix(transmitted,vec3(1.),.72),transmitted*(.20+.28*smoothstep(-.55,.8,p.y/max(halfSize.y,1.))+rim*.28)+vec3(.008,.006,.011),uDark);
  float fresnel=.035+.965*pow(1.-n.z,5.);
  glass+=mix(vec3(.25,.16,.24),uPeach,.5+.5*g.y)*fresnel*.24*uReflection;
  float line=exp(-pow((d+.65)/.55,2.));
  glass+=vec3(.62,.65,.78)*line*uReflection*.6;
  float mask=1.-smoothstep(-.65,.65,d);
  fragColor=vec4(clamp(glass,0.,1.)*mask,mask);
}
