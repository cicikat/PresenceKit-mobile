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
mat2 rot(float a){float c=cos(a),s=sin(a);return mat2(c,-s,s,c);}
float sheet(vec2 p,vec2 center,vec2 size,float angle){
 p=rot(angle)* (p-center);
 p.x+=.065*sin(p.y*2.8+phase)*sin(p.y*1.4+.6);
 return (length(p/size)-1.)*min(size.x,size.y);
}
float surface(vec2 p){
 float a=sheet(p,vec2(-.50,-.46),vec2(.30,1.04),-.13+.025*sin(phase));
 float b=sheet(p,vec2(.37,-.30),vec2(.46,.87),.18+.03*cos(phase));
 float c=sheet(p,vec2(-.20,-1.49),vec2(.44,.60),-.32+.025*cos(phase));
 return min(a,min(b,c));
}
vec3 lightField(vec2 p){
 vec3 c=vec3(.946,.951,.969);
 float path=.20+.29*sin(p.y*1.65+.23*sin(phase))+.08*cos(p.y*3.3-.17*cos(phase));
 float d=p.x-path;
 float violet=exp(-pow((d+.16)*4.1,2.));
 float silver=exp(-pow((d-.04)*10.,2.));
 float rose=exp(-pow((d-.11)*6.5,2.))*exp(-pow((p.y+.65)*.85,2.));
 c=mix(c,vec3(.77,.71,.87),violet*.48);
 c=mix(c,vec3(.98,.967,.983),silver*.61);
 c=mix(c,vec3(.94,.78,.77),rose*.36);
 float left=-.66+.14*sin(p.y*2.1+.20*cos(phase));
 float fold=exp(-pow((p.x-left)*7.,2.))*exp(-pow((p.y+1.)*.7,2.));
 c=mix(c,vec3(.80,.85,.94),fold*.36);
 return c;
}
void main(){
 vec2 p=(gl_FragCoord.xy*2.-resolution.xy)/resolution.y*2.15;
 vec3 color=lightField(p);
 float d=surface(p);
 vec2 e=vec2(.003,0.);
 vec2 grad=normalize(vec2(surface(p+e.xy)-surface(p-e.xy),surface(p+e.yx)-surface(p-e.yx)));
 float cover=1.-smoothstep(-.002,.005,d);
 // Thin optical skin: essentially clear centres, stronger refraction only
 // at the curved edges. There is no opaque mass or thick toroidal body.
 float bend=exp(-max(-d,0.)*9.);
 vec2 lens=p+grad*(.025+.115*bend)+vec2(.018*sin(p.y*3.+phase),0.);
 vec3 through=lightField(lens);
 color=mix(color,through,cover*.82);
 float innerGlow=exp(-pow((d+.045)*34.,2.));
 float edge=exp(-pow(d*185.,2.));
 float shade=exp(-pow((d-.011)*100.,2.));
 float illumination=.5+.5*dot(grad,normalize(vec2(-.6,.8)));
 color-=vec3(.08,.078,.09)*shade*.34;
 color=mix(color,vec3(1.,.995,1.),edge*(.40+.48*illumination));
 color+=vec3(.036,.029,.04)*innerGlow*cover*illumination;
 // A refracted ribbon of light inside each transparent sheet.
 float streak=exp(-pow((lens.x-.23-.27*sin(lens.y*1.65+.23*sin(phase)))*15.,2.));
 color+=vec3(.034,.02,.027)*streak*cover;
 float top=smoothstep(.4,1.9,p.y);
 color=mix(color,vec3(.967,.970,.981),top*.8);
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