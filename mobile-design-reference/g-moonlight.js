/* Standalone visual study. No networking, storage or chat business logic. */
(() => {
'use strict';
const canvas=document.querySelector('#liquid'),device=document.querySelector('.device');
const status=document.querySelector('#renderStatus');
const reduce=matchMedia('(prefers-reduced-motion: reduce)');
let paused=false,frame=0,phase=0,last=0,disposed=false,gl,program,loc,eventActive=false;
let panelData=new Float32Array(40),radiusData=new Float32Array(10),specialData=new Float32Array(10);
const vertex=`attribute vec2 position;void main(){gl_Position=vec4(position,0.,1.);}`;
const fragment=`
precision highp float;
uniform vec2 resolution;
uniform vec2 viewport;
uniform float phase;
uniform float uiVisible;
uniform float eventActive;
uniform vec4 panels[10];
uniform float radii[10];
uniform float special[10];
float roundedBox(vec2 p,vec2 halfSize,float r){vec2 q=abs(p)-halfSize+r;return length(max(q,0.))+min(max(q.x,q.y),0.)-r;}
float river(vec2 p){
 float spine=.58*sin(phase)+.52*sin(p.y*1.12+.40*cos(phase))+.16*sin(p.y*2.7-.38*sin(phase));
 return p.x-spine;
}
float energy(vec2 p){return exp(-pow(river(p)*1.9,2.));}
vec3 lightField(vec2 p){
 vec3 c=vec3(.943,.950,.971);
 float d=river(p);
 float violet=exp(-pow((d+.24)*1.75,2.));
 float blue=exp(-pow((d+.65)*2.1,2.));
 float pearl=exp(-pow((d-.02)*4.6,2.));
 float rose=exp(-pow((d-.31)*2.75,2.))*(.65+.35*sin(p.y*1.2+phase));
 c=mix(c,vec3(.75,.69,.86),violet*.66);
 c=mix(c,vec3(.77,.86,.94),blue*.25);
 c=mix(c,vec3(.985,.970,.987),pearl*.61);
 c=mix(c,vec3(.955,.785,.783),rose*.48);
 float fold=exp(-pow((d+.07+.13*sin(p.y*2.+phase))*8.,2.));
 c+=vec3(.027,.023,.030)*fold;
 // The light crosses almost the whole display; top remains quiet for status.
 float top=smoothstep(.85,2.05,p.y);
 return mix(c,vec3(.960,.965,.978),top*.68);
}
void main(){
 vec2 pixel=vec2(gl_FragCoord.x/resolution.x*viewport.x,(1.-gl_FragCoord.y/resolution.y)*viewport.y);
 vec2 p=(gl_FragCoord.xy*2.-resolution.xy)/resolution.y*2.15;
 vec3 color=lightField(p);
 for(int i=0;i<10;i++){
  vec4 box=panels[i];
  if(box.z>0.&&uiVisible>.5){
   vec2 local=pixel-box.xy-box.zw*.5;
   float r=min(radii[i],min(box.z,box.w)*.5);
   float d=roundedBox(local,box.zw*.5,r);
   float cover=1.-smoothstep(-.7,.7,d);
   if(d<3.){
    vec2 normal=normalize(vec2(roundedBox(local+vec2(.5,0.),box.zw*.5,r)-roundedBox(local-vec2(.5,0.),box.zw*.5,r),roundedBox(local+vec2(0.,.5),box.zw*.5,r)-roundedBox(local-vec2(0.,.5),box.zw*.5,r))+vec2(.0001));
    normal.y=-normal.y;
    float bend=exp(-max(-d,0.)/8.);
    vec2 lens=p+normal*(.020+.105*bend);
    vec3 transmitted=lightField(lens);
    float rarer=special[i]*eventActive;
    if(rarer>.5){
     // An exceptional optical response, driven by THE SAME river, not an
     // unrelated rainbow animation: the passing wave changes spectrum.
     float wave=energy(lens);
     float spectral=river(lens)*3.4+lens.y*.95;
     vec3 rainbow=.5+.5*cos(spectral+vec3(0.,2.094,4.188));
     vec3 inverted=vec3(.25,.22,.36)+(1.-transmitted)*.43;
     transmitted=mix(inverted,inverted+rainbow*.43,wave*.86);
    }
    color=mix(color,transmitted,cover*.93);
    float edge=exp(-pow(d*1.5,2.));
    float inner=exp(-pow((d+2.0)*.64,2.));
    float lit=.55+.45*dot(normal,normalize(vec2(-.6,.8)));
    color+=vec3(.08)*edge*lit+vec3(.032)*inner*cover*lit;
    color-=vec3(.026,.024,.03)*exp(-pow((d-1.2)*1.3,2.));
   }
  }
 }
 gl_FragColor=vec4(clamp(color,0.,1.),1.);
}`;
function shader(type,source){const s=gl.createShader(type);gl.shaderSource(s,source);gl.compileShader(s);if(!gl.getShaderParameter(s,gl.COMPILE_STATUS))throw Error(gl.getShaderInfoLog(s));return s;}
function init(){
 gl=canvas.getContext('webgl',{alpha:false,antialias:false,depth:false,powerPreference:'low-power',preserveDrawingBuffer:true});
 if(!gl)throw Error('WebGL unavailable');
 program=gl.createProgram();const vs=shader(gl.VERTEX_SHADER,vertex),fs=shader(gl.FRAGMENT_SHADER,fragment);gl.attachShader(program,vs);gl.attachShader(program,fs);gl.linkProgram(program);if(!gl.getProgramParameter(program,gl.LINK_STATUS))throw Error(gl.getProgramInfoLog(program));gl.useProgram(program);gl.deleteShader(vs);gl.deleteShader(fs);
 const buffer=gl.createBuffer();gl.bindBuffer(gl.ARRAY_BUFFER,buffer);gl.bufferData(gl.ARRAY_BUFFER,new Float32Array([-1,-1,1,-1,-1,1,-1,1,1,-1,1,1]),gl.STATIC_DRAW);const attr=gl.getAttribLocation(program,'position');gl.enableVertexAttribArray(attr);gl.vertexAttribPointer(attr,2,gl.FLOAT,false,0,0);loc={res:gl.getUniformLocation(program,'resolution'),phase:gl.getUniformLocation(program,'phase'),viewport:gl.getUniformLocation(program,'viewport'),panels:gl.getUniformLocation(program,'panels[0]'),radii:gl.getUniformLocation(program,'radii[0]'),special:gl.getUniformLocation(program,'special[0]'),visible:gl.getUniformLocation(program,'uiVisible'),event:gl.getUniformLocation(program,'eventActive')};
 document.querySelector('.fallback').style.display='none';canvas.style.display='block';
 resize();syncMotion();
}
function draw(){if(disposed||gl.isContextLost())return;gl.uniform2f(loc.res,canvas.width,canvas.height);gl.uniform1f(loc.phase,phase);gl.uniform2f(loc.viewport,device.clientWidth,device.clientHeight);gl.uniform4fv(loc.panels,panelData);gl.uniform1fv(loc.radii,radiusData);gl.uniform1fv(loc.special,specialData);gl.uniform1f(loc.visible,device.classList.contains("background-only")?0:1);gl.uniform1f(loc.event,eventActive?1:0);gl.drawArrays(gl.TRIANGLES,0,6);}
function measurePanels(){const parent=device.getBoundingClientRect();panelData.fill(0);document.querySelectorAll(".nav.glass,.bubble.glass,.dream-card.glass,.composer .glass").forEach((el,i)=>{if(i>=10)return;const r=el.getBoundingClientRect();panelData.set([r.left-parent.left,r.top-parent.top,r.width,r.height],i*4);radiusData[i]=parseFloat(getComputedStyle(el).borderTopLeftRadius)||24;specialData[i]=el.classList.contains("dream-card")?1:0;});}
function resize(){if(!gl||disposed)return;const r=device.getBoundingClientRect();const scale=Math.min(1.15,devicePixelRatio,420/r.width);canvas.width=Math.round(r.width*scale);canvas.height=Math.round(r.height*scale);gl.viewport(0,0,canvas.width,canvas.height);measurePanels();draw();}
function loop(now){frame=0;if(document.hidden||paused||reduce.matches||disposed)return;if(!last)last=now;const delta=now-last;if(delta>=1000/24){phase=(phase+Math.min(delta,100)/24000*Math.PI*2)%(Math.PI*2);last=now;draw();}frame=requestAnimationFrame(loop);}
function syncMotion(){cancelAnimationFrame(frame);frame=0;last=0;const still=paused||reduce.matches;document.body.classList.toggle('motion-off',still);const b=document.querySelector('#motionToggle');b.setAttribute('aria-pressed',String(still));b.innerHTML=reduce.matches?'系统已减少动态 <span>○</span>':paused?'继续流动 <span>▷</span>':'暂停流动 <span>Ⅱ</span>';b.disabled=reduce.matches;status.textContent=disposed?'静态 SVG 降级 / WebGL 不可用':still?'静止曲面 / 减少动态':'全幅光流 · UI 玻璃折射 / 24 秒循环';if(!still&&!document.hidden&&!disposed)frame=requestAnimationFrame(loop);}
function fallback(error){disposed=true;cancelAnimationFrame(frame);canvas.style.display='none';document.querySelector('.fallback').style.display='block';status.textContent='静态 SVG 降级 / WebGL 不可用';console.warn('Moonlight WebGL fallback:',error.message);}
try{init();}catch(error){fallback(error);}
new ResizeObserver(resize).observe(device);
reduce.addEventListener('change',syncMotion);document.addEventListener('visibilitychange',syncMotion);
canvas.addEventListener('webglcontextlost',event=>{event.preventDefault();fallback(Error('Context lost'));});
canvas.addEventListener('webglcontextrestored',()=>{disposed=false;try{init();}catch(error){fallback(error);}});
document.querySelector('#motionToggle').addEventListener('click',()=>{paused=!paused;syncMotion();});
document.querySelector('#backgroundToggle').addEventListener('click',event=>{const active=device.classList.toggle('background-only');const ui=document.querySelector('#phoneUI');ui.inert=active;ui.setAttribute('aria-hidden',String(active));event.currentTarget.setAttribute('aria-pressed',String(active));event.currentTarget.innerHTML=active?'返回梦境界面 <span>↙</span>':'纯背景预览 <span>↗</span>';draw();});
document.querySelector(".conversation").addEventListener("scroll",()=>{measurePanels();draw();},{passive:true});
document.querySelector("#eventToggle").addEventListener("click",event=>{eventActive=!eventActive;device.classList.toggle("rare-event",eventActive);event.currentTarget.setAttribute("aria-pressed",String(eventActive));event.currentTarget.innerHTML=eventActive?"收起稀有事件 <span>✧</span>":"预览稀有事件 <span>✧</span>";document.querySelector(".card-copy small").textContent=eventActive?"A RARE MOMENT":"OUR LITTLE REVERIE";document.querySelector(".card-copy strong").textContent=eventActive?"梦境交汇":"月下庭院";document.querySelector("#cardStatus").textContent=eventActive?"这一刻，月光有了新的颜色。":"月光很轻，你也不必匆忙。";measurePanels();draw();});
let toastTimer;
function toast(text){const el=document.querySelector('.toast');el.textContent=text;el.classList.add('show');clearTimeout(toastTimer);toastTimer=setTimeout(()=>el.classList.remove('show'),2200);}
document.querySelectorAll('button').forEach(b=>{b.addEventListener('pointerdown',()=>b.classList.add('pressed'));['pointerup','pointercancel','pointerleave','blur'].forEach(name=>b.addEventListener(name,()=>b.classList.remove('pressed')));b.addEventListener('click',()=>{if(b.dataset.demo)toast(b.dataset.demo);});});
document.querySelector('.dream-card').addEventListener('click',event=>{const b=event.currentTarget,open=b.getAttribute('aria-expanded')!=='true';b.setAttribute('aria-expanded',String(open));document.querySelector('#cardStatus').textContent=open?'梦境很安静 · 叶瑄在你身边':'月光很轻，你也不必匆忙。';});
document.querySelector('input').addEventListener('keydown',event=>{if(event.key==='Enter')toast('这里只预览心意，不发送真实消息');});
})();