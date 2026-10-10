/* Offline art directions; no app state or backend. */
const DESIGNS = [
 {id:'c1',mode:2,name:'金色剧场',en:'AFTER HOURS',tag:'暖金 · 全屏舞台 · 底部对白',colors:['#794720','#c99046','#fff0be'],layout:'theatre',title:'今夜，<br>只听见你。',desc:'把世界的声音关小一点。',accent:'#edc77d'},
 {id:'c2',mode:2,name:'冰蓝留白',en:'BLUE SILENCE',tag:'冰蓝 · 侧边时间轴 · 极简气泡',colors:['#164b83','#57b6de','#d7f6ff'],layout:'timeline',title:'慢一点。',desc:'02:17 / 时间暂停在这里',accent:'#a9e8ff'},
 {id:'c3',mode:2,name:'朱红书信',en:'LETTERS IN A DREAM',tag:'朱红 · 书信排版 · 纸页输入',colors:['#5e1426','#c93b47','#f8a775'],layout:'letter',title:'致，<br>梦里的你',desc:'第二十七封 / 尚未寄出',accent:'#e69b87'},
 {id:'c4',mode:2,name:'薄荷终端',en:'LUCID / 004',tag:'薄荷 · 分区终端 · 等宽排版',colors:['#10463f','#41a790','#d3ffb6'],layout:'terminal',title:'梦境已展开_',desc:'CHANNEL 04 · 夜间漫游',accent:'#b6ffce'},
 {id:'f1',mode:0,name:'奶油梦卡',en:'SOFT LANDING',tag:'奶油杏 · 堆叠卡片 · 柔和圆角',colors:['#895443','#cc8c6c','#ffe2af'],layout:'cards',title:'落进一个<br>柔软的梦',desc:'今天，可以不用那么勇敢。',accent:'#ffdeb6'},
 {id:'f2',mode:0,name:'靛蓝轨道',en:'BETWEEN STARS',tag:'靛蓝 · 环形导航 · 中央对话',colors:['#232d83','#7764d6','#8be7f4'],layout:'orbit',title:'我们之间<br>没有距离',desc:'沿着光，慢慢靠近。',accent:'#b7bdff'},
 {id:'f3',mode:0,name:'珊瑚杂志',en:'DREAM / ISSUE 08',tag:'珊瑚橙 · 编辑网格 · 大字排版',colors:['#822d25','#ec6842','#ffce66'],layout:'editorial',title:'今晚<br>去远方。',desc:'一场没有目的地的夜游',accent:'#ffb28b'},
 {id:'f4',mode:0,name:'黑白切片',en:'THE OTHER SIDE',tag:'银灰 · 上下分屏 · 白色对话台',colors:['#282b32','#737b86','#f0eee7'],layout:'split',title:'醒来之前',desc:'让这一刻，再长一些。',accent:'#eeeae2'}
];
const d = DESIGNS.find(x=>x.id===new URLSearchParams(location.search).get('id')) || DESIGNS[0];
window.FLOW_CONFIG={mode:d.mode,violet:d.colors[0],magenta:d.colors[1],peach:d.colors[2],thickness:18,transmission:.58};
document.title=d.name+' · 梦境 UI';
document.body.className=d.layout;
document.documentElement.style.setProperty('--accent',d.accent);
const dialogue='<article class="message incoming glass"><span class="speaker">叶暄 / YEXUAN</span><p>你来了。<br>这里的时间，走得很慢。</p></article><article class="message outgoing glass"><p>我想再待一会儿。</p></article><article class="message incoming glass"><p>那就留下来。<br>今晚的风，会替你保守秘密。</p></article>';
const banner=`<div class="hero"><span class="kicker">${d.en}</span><h1>${d.title}</h1><p>${d.desc}</p></div>`;
const chapter='<button class="chapter" id="fragment"><span>梦境片段 / 01</span><strong>海边没有尽头的车站</strong><span>探索片段 ↗</span></button>';
const conversation=`<section class="conversation" aria-label="梦境对话"><div class="date">今夜 · 02:17</div><div id="messages" aria-live="polite">${dialogue}</div></section>`;
const header=`<header><a href="index.html" aria-label="返回八套总览">‹</a><span>梦境<span class="live">● 与你同在</span></span><button id="settings" aria-label="打开视觉设置">···</button></header>`;
const composer='<div class="bottom"><div class="hint">轻轻说，不必解释</div><form class="composer glass" id="composer"><button type="button" id="prompt" aria-label="插入梦境提示">✧</button><input aria-label="梦境消息" placeholder="说说你的梦…" maxlength="180" autocomplete="off"><button class="send" aria-label="发送演示消息">↑</button></form><div class="home"></div></div>';
const structures={theatre:banner+conversation,timeline:banner+'<div class="timeline-label">NOW<br>│<br>02:17</div>'+conversation,letter:banner+'<div class="letter-rule">亲爱的你：</div>'+conversation+'<div class="signature">愿我们在梦里重逢。<br>叶暄</div>',terminal:banner+'<div class="systemline">[ SESSION OPEN ] <span>∞</span></div>'+conversation+chapter,cards:banner+chapter+conversation,orbit:banner+'<div class="orbit-mark"><span>✧</span><small>同一片星光</small></div>'+conversation,editorial:banner+chapter+conversation,split:banner+'<div class="sheet">'+conversation+'</div>'};
document.querySelector('#app').innerHTML=`<main class="dream"><canvas id="scene" aria-hidden="true"></canvas><div id="failure" hidden>动态背景不可用，当前显示静态配色。</div><div class="ui">${header}<div class="content">${structures[d.layout]}</div>${composer}</div><dialog id="controls"><form method="dialog"><h2>此刻的光 <button aria-label="关闭设置">×</button></h2></form><p>视觉演示 · 本地消息</p><button id="motion">暂停流体</button><button id="reset">重新开始对话</button><div hidden><select id="shape"><option value="0">流体</option><option value="2">卷曲</option></select><button id="reseed">换种子</button>${['thickness','reflection','speed','violet','magenta','peach'].map(k=>`<input id="${k}" type="${['violet','magenta','peach'].includes(k)?'color':'range'}">`).join('')}<button id="defaults">恢复</button></div></dialog><dialog id="fragment-dialog"><form method="dialog"><button aria-label="关闭梦境片段">×</button></form><span class="kicker">DREAM FRAGMENT / 01</span><h2>海边没有尽头的车站</h2><p>末班车还没有来。海浪沿着铁轨，带来一封没有署名的信。</p><button id="use-fragment">从这个梦开始 ↗</button></dialog></main><aside class="design-note"><a href="index.html">← 八套总览</a><span>${d.mode===2?'经典卷曲':'伪随机流体'} / ${d.id.toUpperCase()}</span><h2>${d.name}</h2><p>${d.tag}</p><p>独立视觉稿 · 消息仅在此页面演示</p><nav>${DESIGNS.map(x=>`<a ${x.id===d.id?'aria-current="page"':''} href="design.html?id=${x.id}">${x.id.toUpperCase()} ${x.name}</a>`).join('')}</nav></aside>`;
document.querySelector('#fragment')?.addEventListener('click',()=>document.querySelector('#fragment-dialog').showModal());
document.querySelector('#use-fragment').onclick=()=>{document.querySelector('.composer input').value='我梦见了海边没有尽头的车站。';document.querySelector('#fragment-dialog').close();document.querySelector('.composer input').focus();};
// Keep input and review controls usable when WebGL is unavailable.
const localMessages=document.querySelector('#messages'),localInitial=localMessages.innerHTML;
document.querySelector('#settings').onclick=()=>document.querySelector('#controls').showModal();
document.querySelector('#reset').onclick=()=>{localMessages.innerHTML=localInitial;document.querySelector('.composer input').value='';};
document.querySelector('#prompt').onclick=()=>{document.querySelector('.composer input').value='梦里的光，是什么颜色？';document.querySelector('.composer input').focus();};
document.querySelector('#motion').onclick=()=>{document.querySelector('#motion').textContent='动态背景不可用';};
document.querySelector('#composer').onsubmit=e=>{e.preventDefault();const input=document.querySelector('.composer input');if(!input.value.trim())return;const article=document.createElement('article');article.className='message outgoing glass';const p=document.createElement('p');p.textContent=input.value.trim();article.append(p);localMessages.append(article);input.value='';const area=document.querySelector('.conversation');area.scrollTop=area.scrollHeight;};
