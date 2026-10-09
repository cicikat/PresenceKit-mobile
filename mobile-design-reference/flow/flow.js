/* Independent procedural renderer. No images, libraries, network or app APIs. */
(() => {
  'use strict';
  const DEFAULTS = Object.freeze({thickness:24, bevel:23, reflection:.95, ior:1.46, dispersion:.018, transmission:.46, speed:.24, violet:'#901eb1', magenta:'#fa56f4', peach:'#ffae85'});
  const params = {...DEFAULTS};
  const canvas = document.querySelector('#scene');
  const stage = document.querySelector('.dream');
  const gl = canvas.getContext('webgl2', {alpha:false, antialias:false, preserveDrawingBuffer:true});
  if (!gl) {document.querySelector('#failure').hidden=false; return;}
  const vs = `#version 300 es
  precision highp float;
  out vec2 uv;
  void main(){vec2 p=vec2(float((gl_VertexID<<1)&2),float(gl_VertexID&2)); uv=p; gl_Position=vec4(p*2.-1.,0.,1.);}`;
  const common = `
  precision highp float;
  in vec2 uv;
  out vec4 color;
  uniform vec2 resolution;
  uniform float time;
  uniform vec3 violet,magenta,peach;
  float box(vec2 p,vec2 b,float r){vec2 q=abs(p)-b+r;return length(max(q,0.))+min(max(q.x,q.y),0.)-r;}
  mat2 rot(float a){return mat2(cos(a),-sin(a),sin(a),cos(a));}
  float ellipse(vec2 p,vec2 r){return (length(p/r)-1.)*min(r.x,r.y);}
  `;
  const bg = `#version 300 es
  ${common}
  void main(){
    vec2 p=vec2(uv.x,1.-uv.y)*vec2(430.,860.);
    float t=time;
    // Coherent domain warp: the same moving radiance is sampled by every glass.
    p+=vec2(22.*sin(p.y*.008+t*.9)+9.*sin(p.y*.019-t*.6),18.*sin(p.x*.008+t*.7)+8.*sin(p.x*.024-t*.5));
    vec3 c=vec3(.002,.001,.003);
    vec2 q=rot(-.36+.14*sin(t*.6))*(p-vec2(175.+18.*sin(t),255.+20.*sin(t*.65)));
    float ring=ellipse(q,vec2(96.+9.*sin(t*.8),140.+14.*sin(t*.55)));
    float band=exp(-pow(ring/22.,2.));
    c+=mix(violet,magenta,smoothstep(-70.,70.,q.y)) * band*.75;
    c+=violet*exp(-pow(ring/42.,2.))*.19;
    // Tall folded peach ribbon, with a magenta envelope and black negative space.
    float cx=251.+(53.+14.*sin(t*.45))*sin((p.y-200.)*(.010+.0015*sin(t*.35))+t*.6);
    float dx=p.x-cx;
    float gate=smoothstep(100.,200.,p.y)*(1.-smoothstep(680.,810.,p.y));
    float shape=exp(-pow(abs(dx)/43.,4.))*gate;
    float envelope=exp(-pow(dx/72.,2.))*gate;
    float pink=exp(-pow((dx+28.)/25.,2.));
    vec3 ribbon=mix(peach,magenta,pink*.78);
    c+=magenta*envelope*.52;
    c=mix(c,ribbon,shape*.92);
    vec2 q2=rot(.27+.14*sin(t*.55))*(p-vec2(160.+12.*sin(t*.7),625.+18.*cos(t*.6)-18.));
    float d2=ellipse(q2,vec2(75.,115.));
    float lowerRing=exp(-pow(d2/27.,2.))*.60;
    c=mix(c,mix(magenta,peach,smoothstep(-30.,70.,q2.x)),lowerRing);
    // Peripheral falloff retains Apple's deep black rather than filling the screen.
    float vignette=1.-smoothstep(165.,250.,abs(p.x-215.));
    c*=vignette;
    color=vec4(clamp(c,0.,1.),1.);
  }`;
  const material = `#version 300 es
  ${common}
  uniform sampler2D backdrop;
  uniform int count;
  uniform vec4 shapes[24];
  uniform vec4 clips[24];
  uniform float radii[24];
  uniform float thickness,bevel,reflection,ior,dispersion,transmission;
  uniform int debug;
  vec3 sampleAt(vec2 p){return texture(backdrop,clamp(vec2(p.x/resolution.x,1.-p.y/resolution.y),vec2(.001),vec2(.999))).rgb;}
  void main(){
    vec2 p=vec2(uv.x,1.-uv.y)*resolution;
    vec3 behind=sampleAt(p);
    float d=1e6;vec2 local=vec2(0.);vec2 halfSize=vec2(1.);float radius=1.;
    for(int i=0;i<24;i++){if(i>=count)break;if(p.x<clips[i].x||p.y<clips[i].y||p.x>clips[i].z||p.y>clips[i].w)continue;vec2 lp=p-shapes[i].xy;float next=box(lp,shapes[i].zw,radii[i]);if(next<d||(i==count-1&&next<.65)){d=next;local=lp;halfSize=shapes[i].zw;radius=radii[i];}}
    if(d>1.2){color=vec4(behind,1.);return;}
    float e=.35;
    vec2 g=normalize(vec2(box(local+vec2(e,0.),halfSize,radius)-box(local-vec2(e,0.),halfSize,radius),box(local+vec2(0.,e),halfSize,radius)-box(local-vec2(0.,e),halfSize,radius))+1e-6);
    float bw=min(bevel,min(halfSize.x,halfSize.y)*.8);
    float a=clamp(-d/bw,0.,1.);
    float ct=1.-a;
    float h=sqrt(max(1.-ct*ct,.001));
    float slope=thickness/bw*ct/max(h,.10);
    // Concave meniscus draws surroundings into the edge; slight dome preserves
    // an optical displacement inside the plateau as well.
    vec3 n=normalize(vec3(-g*slope+local/halfSize*.08,1.));
    float path=thickness*mix(.4,1.,h)*2.7;
    vec3 rr=refract(vec3(0.,0.,-1.),n,1./(ior-dispersion));
    vec3 rg=refract(vec3(0.,0.,-1.),n,1./ior);
    vec3 rb=refract(vec3(0.,0.,-1.),n,1./(ior+dispersion));
    vec2 offR=rr.xy/max(-rr.z,.2)*path;
    vec2 offG=rg.xy/max(-rg.z,.2)*path;
    vec2 offB=rb.xy/max(-rb.z,.2)*path;
    vec3 transmitted=vec3(sampleAt(p+offR).r,sampleAt(p+offG).g,sampleAt(p+offB).b);
    float rim=exp(-max(-d,0.)/9.);
    // Smoked glass, brightest at the bottom and at the curved optical rim.
    float lower=smoothstep(-.55,.8,local.y/halfSize.y);
    float lightThrough=mix(.16,transmission,lower)+rim*.28;
    vec3 glass=transmitted*lightThrough+vec3(.008,.006,.011);
    glass*=mix(.48,1.,smoothstep(1.,6.,-d));
    float fresnel=.035+.965*pow(1.-n.z,5.);
    vec3 env=mix(vec3(.25,.16,.24),peach,.5+.5*g.y);
    glass+=env*fresnel*.24*reflection;
    vec3 light=normalize(vec3(-.55,-.7,1.1));
    float spec=pow(max(dot(n,normalize(light+vec3(0.,0.,1.))),0.),32.);
    glass+=vec3(1.,.87,.83)*spec*.16*reflection*(1.-a);
    // Separate subpixel exterior highlight and inner dark seam, no CSS shadows.
    float line=exp(-pow((d+.65)/.55,2.));
    float directional=.22+.78*pow(abs(dot(g,normalize(vec2(-.6,-.8)))),3.);
    glass+=(vec3(.62,.54,.60)+transmitted*.28)*line*directional*reflection;
    float inner=exp(-pow((d+3.1)/1.1,2.));
    glass+=transmitted*inner*.15*reflection;
    if(debug==1)glass=n*.5+.5;
    if(debug==2)glass=vec3(abs(offG)/40.,0.);
    float mask=1.-smoothstep(-.65,.65,d);
    color=vec4(mix(behind,glass,mask),1.);
  }`;
  function program(fragment){
    const p=gl.createProgram();
    for(const [kind,source] of [[gl.VERTEX_SHADER,vs],[gl.FRAGMENT_SHADER,fragment]]){const s=gl.createShader(kind);gl.shaderSource(s,source);gl.compileShader(s);if(!gl.getShaderParameter(s,gl.COMPILE_STATUS))throw new Error(gl.getShaderInfoLog(s));gl.attachShader(p,s);}
    gl.linkProgram(p);if(!gl.getProgramParameter(p,gl.LINK_STATUS))throw new Error(gl.getProgramInfoLog(p));return p;
  }
  let background,glass;
  try{background=program(bg);glass=program(material);}catch(error){document.querySelector('#failure').hidden=false;document.querySelector('#failure').textContent=error.message;console.error(error);return;}
  const texture=gl.createTexture(),fbo=gl.createFramebuffer();
  gl.bindTexture(gl.TEXTURE_2D,texture);
  for(const [key,value] of [[gl.TEXTURE_MIN_FILTER,gl.LINEAR],[gl.TEXTURE_MAG_FILTER,gl.LINEAR],[gl.TEXTURE_WRAP_S,gl.CLAMP_TO_EDGE],[gl.TEXTURE_WRAP_T,gl.CLAMP_TO_EDGE]])gl.texParameteri(gl.TEXTURE_2D,key,value);
  gl.bindFramebuffer(gl.FRAMEBUFFER,fbo);gl.framebufferTexture2D(gl.FRAMEBUFFER,gl.COLOR_ATTACHMENT0,gl.TEXTURE_2D,texture,0);
  const loc=(p,n)=>gl.getUniformLocation(p,n);
  const hex=s=>[1,3,5].map(i=>parseInt(s.slice(i,i+2),16)/255);
  let width=0,height=0,clock=0,playing=false,previous=performance.now(),frame=0,raf=0;
  const reduced=matchMedia('(prefers-reduced-motion: reduce)');
  const query=new URLSearchParams(location.search);
  const controls=document.querySelector('#controls');
  function render(){
    const bounds=stage.getBoundingClientRect();
    const dpr=Math.min(devicePixelRatio,2);
    const w=Math.round(bounds.width*dpr),h=Math.round(bounds.height*dpr);
    if(w!==width||h!==height){width=w;height=h;canvas.width=w;canvas.height=h;gl.bindTexture(gl.TEXTURE_2D,texture);gl.texImage2D(gl.TEXTURE_2D,0,gl.RGBA8,w,h,0,gl.RGBA,gl.UNSIGNED_BYTE,null);}
    gl.viewport(0,0,width,height);
    gl.useProgram(background);gl.uniform2f(loc(background,'resolution'),bounds.width,bounds.height);gl.uniform1f(loc(background,'time'),clock);
    for(const key of ['violet','magenta','peach'])gl.uniform3fv(loc(background,key),hex(params[key]));
    gl.bindFramebuffer(gl.FRAMEBUFFER,fbo);gl.drawArrays(gl.TRIANGLES,0,3);
    gl.bindFramebuffer(gl.FRAMEBUFFER,null);gl.useProgram(glass);gl.activeTexture(gl.TEXTURE0);gl.bindTexture(gl.TEXTURE_2D,texture);gl.uniform1i(loc(glass,'backdrop'),0);
    gl.uniform2f(loc(glass,'resolution'),bounds.width,bounds.height);
    const data=[],radii=[],clips=[];
    const viewport=document.querySelector('.conversation').getBoundingClientRect();
    for(const el of document.querySelectorAll('.glass')){const r=el.getBoundingClientRect();const isMessage=el.classList.contains('message');if(isMessage&&(r.bottom<viewport.top||r.top>viewport.bottom))continue;if(data.length>=96)break;data.push(r.x-bounds.x+r.width/2,r.y-bounds.y+r.height/2,r.width/2,r.height/2);radii.push(Math.min(parseFloat(getComputedStyle(el).borderRadius),r.width/2,r.height/2));clips.push(0,isMessage?viewport.top-bounds.top:0,bounds.width,isMessage?viewport.bottom-bounds.top:bounds.height);}
    gl.uniform1i(loc(glass,'count'),radii.length);gl.uniform4fv(loc(glass,'shapes[0]'),data);gl.uniform1fv(loc(glass,'radii[0]'),radii);
    gl.uniform4fv(loc(glass,'clips[0]'),clips);
    for(const key of ['thickness','bevel','reflection','ior','dispersion','transmission'])gl.uniform1f(loc(glass,key),params[key]);
    gl.uniform3fv(loc(glass,'peach'),hex(params.peach));gl.uniform1i(loc(glass,'debug'),Number(query.get('debug'))||0);gl.drawArrays(gl.TRIANGLES,0,3);
    canvas.dataset.renderer='webgl2';canvas.dataset.frame=String(++frame);canvas.dataset.time=clock.toFixed(3);
  }
  function tick(now){if(!playing||document.hidden)return;const dt=Math.min((now-previous)/1000,.05);previous=now;clock+=dt*params.speed;render();raf=requestAnimationFrame(tick);}
  function setPlaying(on){cancelAnimationFrame(raf);playing=on;previous=performance.now();document.querySelector('#motion').textContent=playing?'暂停流体':'播放流体';render();if(playing&&!document.hidden)raf=requestAnimationFrame(tick);}
  document.querySelector('#motion').onclick=()=>setPlaying(!playing);
  document.querySelector('#settings').onclick=()=>controls.showModal();
  for(const key of ['thickness','reflection','speed','violet','magenta','peach'])document.querySelector('#'+key).oninput=e=>{params[key]=e.target.type==='color'?e.target.value:Number(e.target.value);render();};
  document.querySelector('#defaults').onclick=()=>{Object.assign(params,DEFAULTS);for(const key of ['thickness','reflection','speed','violet','magenta','peach'])document.querySelector('#'+key).value=params[key];clock=0;render();};
  const messages=document.querySelector('#messages'),initial=messages.innerHTML,input=document.querySelector('.composer input');
  document.querySelector('#composer').onsubmit=e=>{e.preventDefault();const value=input.value.trim();if(!value)return;const article=document.createElement('article');article.className='message outgoing glass';const p=document.createElement('p');p.textContent=value;article.append(p);messages.append(article);input.value='';const scroller=document.querySelector('.conversation');scroller.scrollTop=scroller.scrollHeight;render();};
  document.querySelector('#reset').onclick=()=>{messages.innerHTML=initial;input.value='';document.querySelector('.conversation').scrollTop=0;clock=0;render();};
  document.querySelector('#prompt').onclick=()=>{input.value='梦里的光，是什么颜色？';input.focus();};
  document.querySelector('.conversation').addEventListener('scroll',render,{passive:true});
  new ResizeObserver(render).observe(stage);
  new ResizeObserver(render).observe(messages);
  reduced.addEventListener('change',e=>{if(e.matches)setPlaying(false);});
  document.addEventListener('visibilitychange',()=>{cancelAnimationFrame(raf);previous=performance.now();if(!document.hidden){render();if(playing)raf=requestAnimationFrame(tick);}});
  render();
  // Static review completed before enabling slow movement. Deterministic capture:
  // ?static=1. OS reduced-motion preference also keeps the scene still.
  if(query.get('static')!=='1'&&!reduced.matches)setPlaying(true);
})();
