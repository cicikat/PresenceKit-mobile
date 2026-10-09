/* Standalone visual study. No networking, storage or chat business logic. */
(() => {
'use strict';
const canvas=document.querySelector('#liquid'),device=document.querySelector('.device');
const status=document.querySelector('#renderStatus');
const reduce=matchMedia('(prefers-reduced-motion: reduce)');
let paused=false,frame=0,phase=0,last=0,disposed=false,gl,program,loc;
const vertex=`attribute vec2 position;void main(){gl_Position=vec4(position,0.,1.);}`;
const fragment=`
precision highp float;
uniform vec2 resolution;
uniform float phase;
const float PI=3.14159265359;
mat2 rotate(float a){float c=cos(a),s=sin(a);return mat2(c,-s,s,c);}
// A sculpted, uneven toroidal sheet. The opening and folded rim provide
// recognizable glass curvature rather than a set of blurred colour blobs.
float field(vec3 p){
 p.y+=.52;
 p.xy=rotate(-.30+.06*sin(phase))*p.xy;
 p.y/=1.38;
 p.x+=.10*sin(p.y*3.+phase);
 float a=atan(p.y,p.x);
 float ring=.72+.12*sin(a*3.+.4+ .22*sin(phase))+.065*cos(a*2.-.3);
 float thick=.235+.065*sin(a*2.+1.+.3*cos(phase));
 float z=p.z+.16*sin(a*2.+.7)+.07*cos(a*3.+phase);
 return (length(vec2(length(p.xy)-ring,z*.84))-thick)*.72;
}
vec3 normalAt(vec3 p){vec2 e=vec2(.002,0.);return normalize(vec3(field(p+e.xyy)-field(p-e.xyy),field(p+e.yxy)-field(p-e.yxy),field(p+e.yyx)-field(p-e.yyx)));}
vec3 backdrop(vec2 p){
 vec3 c=vec3(.936,.941,.962);
 float violet=exp(-dot((p-vec2(.45,-.5))*vec2(.7,.55),(p-vec2(.45,-.5))*vec2(.7,.55)));
 c=mix(c,vec3(.84,.82,.90),violet*.48);
 float pearl=exp(-dot(p-vec2(-.55,1.1),p-vec2(-.55,1.1))*1.4);
 c=mix(c,vec3(.989,.982,.991),pearl*.75);
 float gold=exp(-dot((p-vec2(-.7,-1.3))*vec2(2.,1.),(p-vec2(-.7,-1.3))*vec2(2.,1.)));
 c=mix(c,vec3(.925,.849,.828),gold*.27);
 return c;
}
// Procedural studio illumination: broad pearl panels, a narrow silver strip,
// and a small rose/champagne panel; all reflected on the curved surface.
vec3 environment(vec3 r){
 float a=atan(r.z,r.x),h=r.y;
 vec3 c=mix(vec3(.51,.54,.65),vec3(.98,.976,.99),smoothstep(-.7,.7,h));
 float strip=pow(.5+.5*cos(a*3.+h*2.+.09*sin(phase)),18.);
 c=mix(c,vec3(1.),strip*.85);
 float dark=pow(.5+.5*cos(a*2.-h*3.+1.),10.);
 c=mix(c,vec3(.40,.42,.53),dark*.46);
 float rose=exp(-pow((a+.9)*2.2,2.)-pow((h+.35)*2.,2.));
 c=mix(c,vec3(.92,.76,.72),rose*.80);
 float lavender=exp(-pow((a-1.8)*1.4,2.)-pow(h*1.7,2.));
 c=mix(c,vec3(.76,.71,.85),lavender*.60);
 return c;
}
void main(){
 vec2 uv=(gl_FragCoord.xy*2.-resolution.xy)/resolution.y;
 uv*=2.15;
 vec3 color=backdrop(uv);
 vec3 origin=vec3(uv,3.6),direction=vec3(0.,0.,-1.);
 float travel=0.;bool hit=false;
 for(int i=0;i<64;i++){vec3 p=origin+direction*travel;float d=field(p);if(d<.0015){hit=true;break;}travel+=d*.9;if(travel>6.)break;}
 if(hit){
  vec3 p=origin+direction*travel,n=normalAt(p);
  float facing=clamp(dot(n,-direction),0.,1.);
  float fresnel=.045+.955*pow(1.-facing,3.6);
  vec3 refracted=refract(direction,n,1./1.46);
  float thickness=.32+.30*facing;
  vec2 lens=uv+refracted.xy*(.65+thickness)+n.xy*.10;
  vec3 transmission=backdrop(lens);
  // Rear-surface reflection and a softly distorted pearl ribbon inside glass.
  vec3 inside=environment(normalize(vec3(refracted.xy*.7,-refracted.z)));
  transmission=mix(transmission,inside,.23);
  float ribbon=exp(-pow((lens.x*.85+lens.y*.52+.37+.025*sin(phase))*8.,2.));
  transmission=mix(transmission,vec3(.93,.80,.77),ribbon*.32);
  float innerSilver=pow(.5+.5*sin(lens.y*4.+lens.x*2.),12.);
  transmission+=vec3(.045,.045,.06)*innerSilver;
  vec3 reflected=environment(reflect(direction,n));
  color=mix(transmission,reflected,.16+fresnel*.66);
  float rim=pow(1.-facing,8.);
  float innerEdge=exp(-pow((facing-.32)*18.,2.));
  color=mix(color,vec3(.71,.70,.79),innerEdge*.20);
  float seam=exp(-pow((facing-.48)*24.,2.));
  color+=vec3(.055,.049,.045)*seam;
  color=mix(color,vec3(.99,.985,1.),rim*.72);
  vec3 light=normalize(vec3(-.65,.85,1.4));
  float spec=pow(max(dot(reflect(direction,n),light),0.),90.);
  color+=vec3(.17)*spec;
  float contour=pow(1.-facing,2.);
  color-=vec3(.15,.14,.13)*contour*(1.-rim);
 }
 // Subtle vignette for spatial depth, without a full-screen blur overlay.
 color-=.018*pow(length(uv)*.32,2.);
 gl_FragColor=vec4(clamp(color,0.,1.),1.);
}`;
function shader(type,source){const s=gl.createShader(type);gl.shaderSource(s,source);gl.compileShader(s);if(!gl.getShaderParameter(s,gl.COMPILE_STATUS))throw Error(gl.getShaderInfoLog(s));return s;}
function init(){
 gl=canvas.getContext('webgl',{alpha:false,antialias:false,depth:false,powerPreference:'low-power',preserveDrawingBuffer:true});
 if(!gl)throw Error('WebGL unavailable');
 program=gl.createProgram();const vs=shader(gl.VERTEX_SHADER,vertex),fs=shader(gl.FRAGMENT_SHADER,fragment);gl.attachShader(program,vs);gl.attachShader(program,fs);gl.linkProgram(program);if(!gl.getProgramParameter(program,gl.LINK_STATUS))throw Error(gl.getProgramInfoLog(program));gl.useProgram(program);gl.deleteShader(vs);gl.deleteShader(fs);
 const buffer=gl.createBuffer();gl.bindBuffer(gl.ARRAY_BUFFER,buffer);gl.bufferData(gl.ARRAY_BUFFER,new Float32Array([-1,-1,1,-1,-1,1,-1,1,1,-1,1,1]),gl.STATIC_DRAW);const attr=gl.getAttribLocation(program,'position');gl.enableVertexAttribArray(attr);gl.vertexAttribPointer(attr,2,gl.FLOAT,false,0,0);loc={res:gl.getUniformLocation(program,'resolution'),phase:gl.getUniformLocation(program,'phase')};
 document.querySelector('.fallback').style.display='none';canvas.style.display='block';
 resize();syncMotion();
}
function draw(){if(disposed||gl.isContextLost())return;gl.uniform2f(loc.res,canvas.width,canvas.height);gl.uniform1f(loc.phase,phase);gl.drawArrays(gl.TRIANGLES,0,6);}
function resize(){if(!gl||disposed)return;const r=device.getBoundingClientRect();const scale=Math.min(1.15,devicePixelRatio,420/r.width);canvas.width=Math.round(r.width*scale);canvas.height=Math.round(r.height*scale);gl.viewport(0,0,canvas.width,canvas.height);draw();}
function loop(now){frame=0;if(document.hidden||paused||reduce.matches||disposed)return;if(!last)last=now;const delta=now-last;if(delta>=1000/24){phase=(phase+Math.min(delta,100)/24000*Math.PI*2)%(Math.PI*2);last=now;draw();}frame=requestAnimationFrame(loop);}
function syncMotion(){cancelAnimationFrame(frame);frame=0;last=0;const still=paused||reduce.matches;document.body.classList.toggle('motion-off',still);const b=document.querySelector('#motionToggle');b.setAttribute('aria-pressed',String(still));b.innerHTML=reduce.matches?'系统已减少动态 <span>○</span>':paused?'继续流动 <span>▷</span>':'暂停流动 <span>Ⅱ</span>';b.disabled=reduce.matches;status.textContent=disposed?'静态 SVG 降级 / WebGL 不可用':still?'静止曲面 / 减少动态':'实时曲面折射 / 24 秒循环';if(!still&&!document.hidden&&!disposed)frame=requestAnimationFrame(loop);}
function fallback(error){disposed=true;cancelAnimationFrame(frame);canvas.style.display='none';document.querySelector('.fallback').style.display='block';status.textContent='静态 SVG 降级 / WebGL 不可用';console.warn('Moonlight WebGL fallback:',error.message);}
try{init();}catch(error){fallback(error);}
new ResizeObserver(resize).observe(device);
reduce.addEventListener('change',syncMotion);document.addEventListener('visibilitychange',syncMotion);
canvas.addEventListener('webglcontextlost',event=>{event.preventDefault();fallback(Error('Context lost'));});
canvas.addEventListener('webglcontextrestored',()=>{disposed=false;try{init();}catch(error){fallback(error);}});
document.querySelector('#motionToggle').addEventListener('click',()=>{paused=!paused;syncMotion();});
document.querySelector('#backgroundToggle').addEventListener('click',event=>{const active=device.classList.toggle('background-only');const ui=document.querySelector('#phoneUI');ui.inert=active;ui.setAttribute('aria-hidden',String(active));event.currentTarget.setAttribute('aria-pressed',String(active));event.currentTarget.innerHTML=active?'返回梦境界面 <span>↙</span>':'纯背景预览 <span>↗</span>';});
let toastTimer;
function toast(text){const el=document.querySelector('.toast');el.textContent=text;el.classList.add('show');clearTimeout(toastTimer);toastTimer=setTimeout(()=>el.classList.remove('show'),2200);}
document.querySelectorAll('button').forEach(b=>{b.addEventListener('pointerdown',()=>b.classList.add('pressed'));['pointerup','pointercancel','pointerleave','blur'].forEach(name=>b.addEventListener(name,()=>b.classList.remove('pressed')));b.addEventListener('click',()=>{if(b.dataset.demo)toast(b.dataset.demo);});});
document.querySelector('.dream-card').addEventListener('click',event=>{const b=event.currentTarget,open=b.getAttribute('aria-expanded')!=='true';b.setAttribute('aria-expanded',String(open));document.querySelector('#cardStatus').textContent=open?'梦境很安静 · 叶瑄在你身边':'月光很轻，你也不必匆忙。';});
document.querySelector('input').addEventListener('keydown',event=>{if(event.key==='Enter')toast('这里只预览心意，不发送真实消息');});
})();