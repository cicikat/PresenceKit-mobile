'use strict';
const style = document.body.dataset.style;
const configs = {
 paper: ['A', '书信阅读', '把日常，慢慢说。', 'LETTERS, BETWEEN US', '像一封不必急着寄出的信。'],
 sage: ['B', '专注聊天', '今天，也在你身边。', 'A LITTLE EVERYDAY', '留一点时间，给自己，也给我们。'],
 night: ['C', '月夜剧场', '夜深了，我还在。', 'UNDER THE SAME MOON', '让白天的喧闹，在这里轻轻落下。'],
 peach: ['D', '生活卡片', '嘿，今天过得好吗？', 'LITTLE THINGS, BIG LOVE', '收集一点快乐，再分享一点给你。']
};
const config = configs[style];
const paths = {
 chat: '<path d="M20 11a8 8 0 0 1-8 8H5l-3 3V11a9 9 0 0 1 18 0Z"/><path d="M7 10h8M7 14h5"/>',
 diary: '<rect x="4" y="3" width="16" height="18" rx="2"/><path d="M8 3v18m4-12h4m-4 4h4"/>',
 garden: '<path d="M12 21V10M12 16C4 17 3 12 3 7c6 0 9 3 9 9Zm0-4c0-6 4-9 9-9 0 6-3 10-9 9Z"/>',
 settings: '<path d="M4 6h16M4 12h16M4 18h16"/><circle cx="9" cy="6" r="2"/><circle cx="16" cy="12" r="2"/><circle cx="8" cy="18" r="2"/>',
 moon: '<path d="M20 15A9 9 0 0 1 9 3a9 9 0 1 0 11 12Z"/>',
 plus: '<path d="M12 5v14M5 12h14"/>',
 send: '<path d="m7 12 5-5 5 5M12 7v12"/>',
 signal: '<path d="M3 17v3m5-7v7m5-12v12m5-17v17"/>',
 battery: '<rect x="2" y="6" width="18" height="12" rx="3"/><path d="M22 10v4M6 10h10v4H6z"/>'
};
function icon(name){return `<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.5" stroke-linecap="round" stroke-linejoin="round" aria-hidden="true">${paths[name]}</svg>`;}
function landscape(isGarden=false){
 const night=style==='night';
 const colors=night?['#243551','#e1def0','#4c6280','#314963','#23364e']:style==='peach'?['#f5dfba','#eaaa59','#b1b38b','#8e9c7a','#667d64']:style==='sage'?['#e0eade','#f4f3d9','#b5c8aa','#7e9f88','#466e5b']:['#ece6d4','#fcf8e9','#c2c5a4','#9aa784','#687e65'];
 return `<svg viewBox="0 0 400 180" preserveAspectRatio="xMidYMid slice" role="img" aria-label="原创${night?'月夜':'山丘'}插画"><rect width="400" height="180" fill="${colors[0]}"/><circle cx="${style==='peach'?300:285}" cy="51" r="${style==='peach'?37:25}" fill="${colors[1]}"/>${night?'<g fill="#bdcde8"><circle cx="52" cy="32" r="1"/><circle cx="151" cy="50" r="1.4"/><circle cx="352" cy="30" r="1"/><circle cx="212" cy="20" r="1"/></g>':''}<path d="M0 120Q90 12 208 101T420 81V180H0" fill="${colors[2]}"/><path d="M0 108Q99 160 220 101T420 126V180H0" fill="${colors[3]}"/><path d="M0 170Q180 100 400 165V180H0" fill="${colors[4]}"/><g fill="none" stroke="${colors[4]}" stroke-width="2"><path d="M66 158V56m0 25Q42 80 42 59q23 1 24 22Zm0 19q25-1 25-22-24 0-25 22"/><path d="M337 165v-50m0 24q-18 0-18-17 18 0 18 17m0 9q19 0 19-18-19 0-19 18"/></g>${isGarden?`<g transform="translate(170 50)"><path d="M30 80V14" stroke="${colors[4]}" stroke-width="4"/><path d="M30 50C-9 51-2 9 30 37M30 31C61 33 68-3 30 15" fill="${colors[4]}"/><path d="M5 74h50l-8 44H13z" fill="${night?'#b0bcda':'#cb9271'}"/><path d="M3 75h54" stroke="${colors[1]}" stroke-width="5"/></g>`:''}${style==='peach'?'<g stroke="#6f492e" fill="none" stroke-linecap="round"><path d="M289 47v3m17-3v3m-15 10q7 6 13 0"/></g>':''}</svg>`;
}
const app=document.querySelector('#app');
app.innerHTML=`<main class="shell ${style}"><div class="status"><span>9:41</span><span>${icon('signal')}${icon('battery')}</span></div><header class="top"><div class="avatar">E.</div><div class="identity"><strong>叶瑄</strong><small><span class="dot"></span>此刻在这里 · 示例状态</small></div><button class="icon-btn" id="dream" aria-label="打开梦境预览">${icon('moon')}</button></header><section class="view" id="view" aria-label="页面内容"></section><div id="chat-tools"><div class="chips"><button class="chip" data-prompt="今天有件小事想告诉你">聊聊今天</button><button class="chip" data-prompt="我们去花园看看吧">去看看花园</button><button class="chip" data-prompt="陪我安静待一会儿吧">安静待一会儿</button></div><form class="composer"><button class="icon-btn" type="button" id="attach" aria-label="附件演示">${icon('plus')}</button><div class="compose-wrap"><input aria-label="输入演示消息" placeholder="想说什么，都可以…" maxlength="600" autocomplete="off"><button class="send" type="submit" aria-label="模拟发送">${icon('send')}</button></div></form></div><nav class="nav" aria-label="主要导航">${[['chat','对话'],['diary','日记'],['garden','花园'],['settings','设置']].map(([key,label])=>`<button data-page="${key}" aria-current="${key==='chat'?'page':'false'}">${icon(key)}${label}</button>`).join('')}</nav><div class="demo">${config[0]} · ${config[1]} / 视觉示范 · 所有内容为示例</div><div class="toast" role="status" hidden></div></main>`;
const view=document.querySelector('#view');
let chatHTML='';
let current='chat';
let toastTimer;
function intro(title,sub,eyebrow){return `<div class="intro"><div class="eyebrow">${eyebrow}</div><h1>${title}</h1><p>${sub}</p></div>`;}
function initialChat(){
 const messages=`<div class="message"><span class="by">叶瑄 · 18:42</span><div class="bubble">刚才路过花店，看见一束很漂亮的洋桔梗。<br>忽然觉得，你应该也会喜欢。</div></div><div class="message mine"><div class="bubble">今天有点累，想在你这里待一会儿。</div><time>18:43</time></div><div class="message"><span class="by">叶瑄 · 18:44</span><div class="bubble">那就先坐一会儿吧。<br>不用急着说什么，我在听。</div></div>`;
 let content='';
 if(style==='paper')content=`<div class="edition"><span>第 009 封</span><span>2026 / 10 / 09</span></div><h1 class="letter-title">把日常，<br><em>慢慢说。</em></h1><div class="letter-meta">TO YOU, WITH LOVE <span>叶瑄 来信</span></div><div class="letter-visual">${landscape()}</div><div class="letter-body"><p class="salutation">亲爱的你，</p>${messages}<p class="signature">一直在这里的，<br><em>叶瑄</em></p></div>`;
 if(style==='sage')content=`<div class="pinned-note"><span>${icon('diary')}</span><div><strong>我们的日常</strong><small>一束洋桔梗，一个普通的傍晚</small></div><button data-page="diary" aria-label="查看相关日记">↗</button></div><div class="date">10 月 9 日 · 星期五</div>${messages}<div class="shared-card"><div class="shared-art">${landscape(true)}</div><div><span class="eyebrow">来自我们的花园</span><strong>小芽又长高了一点</strong><button data-page="garden">一起去看看 →</button></div></div><div class="message"><span class="by">叶瑄 · 18:45</span><div class="bubble">等休息好了，再一起去看看它。<br>今天，我们都可以慢一点。</div></div>`;
 if(style==='night')content=`<div class="immersive-title"><span class="eyebrow">CHAPTER 09 / 月下</span><h1>世界安静下来，<br>只剩下我们。</h1><p>向下走进今晚的故事</p></div><div class="scene-dialogue"><div class="scene-narration">他把手中的书合上，<br>在你身旁，留出一个位置。</div>${messages}</div>`;
 if(style==='peach')content=`<div class="chat-heading"><button class="back-home" data-page="home">← 回到今天</button><h1>和叶瑄聊聊</h1><p>什么小事，都值得被听见。</p></div>${messages}`;
 return content+'<div id="new-messages" aria-live="polite"></div>';
}
function homePage(){return `<div class="home-greeting"><span class="eyebrow">FRIDAY, OCTOBER 09</span><h1>欢迎回到<br>我们的<span>小世界。</span></h1><div class="sun-doodle">☀</div><p>今天，也有一些小事值得期待。</p></div><button class="conversation-tile" data-page="chat"><span class="tile-top"><span class="avatar">E.</span><span>叶瑄留了一句话<small>18:44 · 示例消息</small></span><b>↗</b></span><strong>「不用急着说什么，<br>我在听。」</strong><span class="tile-link">坐下来，聊一会儿 →</span></button><div class="home-grid"><button class="garden-tile" data-page="garden"><span class="tile-label">我们的花园 ↗</span><div>${landscape(true)}</div><strong>又长高一点点</strong><small>第 12 天 · 生长中</small></button><button class="journal-tile" data-page="diary"><span class="tile-label">今日手帐 ↗</span><b>09<span>OCT</span></b><strong>普通的傍晚</strong><small>一束花，一点好心情</small></button></div><button class="dream-tile" data-page="dream">${icon('moon')}<span><strong>今晚的梦，还没开始</strong><small>一起去一个远一点的地方</small></span><b>→</b></button><div class="home-footnote">把普通的日子，过成喜欢的样子。</div>`;}
function applyLayout(page){
 document.querySelector('.shell').dataset.page=page;
 if(style==='peach'&&page==='home')view.innerHTML=homePage();
 if(style==='sage'){document.querySelector('.nav').classList.remove('is-open');document.querySelector('.menu-toggle').setAttribute('aria-expanded','false');}
}
function setupLayout(){
 const top=document.querySelector('.top');
 const nav=document.querySelector('.nav');
 if(style==='paper'){
  top.querySelector('.avatar').remove();
  top.querySelector('.identity').innerHTML='<strong>我们之间<span>the daily letter</span></strong><small>把陪伴，写进日常</small>';
  document.querySelector('.chips').hidden=true;
  document.querySelector('input').placeholder='写下你的回信…';
 }
 if(style==='sage'){
  const menu=document.createElement('button');menu.className='icon-btn menu-toggle';menu.setAttribute('aria-label','展开功能导航');menu.setAttribute('aria-expanded','false');menu.textContent='☰';top.prepend(menu);
  menu.addEventListener('click',()=>{const open=nav.classList.toggle('is-open');menu.setAttribute('aria-expanded',String(open));});
  document.querySelector('.chips').hidden=true;
 }
 if(style==='night'){
  const bg=document.createElement('div');bg.className='world-background';bg.setAttribute('aria-hidden','true');bg.innerHTML='<div class="world-moon"></div><div class="world-ridge back"></div><div class="world-ridge front"></div><div class="world-water"></div><div class="world-stars">·　　　　✧<br>　　　　　·<br>　✧　　　　　·</div>';document.querySelector('.shell').prepend(bg);
  document.querySelector('.chips').hidden=true;
 }
 if(style==='peach'){
  top.querySelector('.identity').innerHTML='<strong>日常俱乐部</strong><small>OUR LITTLE CLUB</small>';
  nav.innerHTML=[['home','今天','garden'],['chat','对话','chat'],['diary','手帐','diary'],['settings','我的','settings']].map(([key,label,svg])=>`<button data-page="${key}">${icon(svg)}${label}</button>`).join('');
 }
}
function render(page){
 if(current==='chat'&&view.innerHTML) chatHTML=view.innerHTML;
 current=page;
 document.querySelector('#chat-tools').hidden=page!=='chat';
 document.querySelectorAll('[data-page]').forEach(b=>b.setAttribute('aria-current',b.dataset.page===page?'page':'false'));
 if(page==='chat') view.innerHTML=chatHTML||initialChat();
 if(page==='diary')view.innerHTML=`${intro('把平凡，留住。','那些微小的瞬间，后来都变得珍贵。','OUR LITTLE JOURNAL')}<div class="scene">${landscape()}</div><div class="eyebrow">OCTOBER 2026 · 共同的日记</div><article class="entry"><div class="day">09<small>FRIDAY</small></div><div><h2>一束花，和一个普通的傍晚</h2><p>今天她说有点累。我想，陪伴有时不需要太多言语，只要把身边的位置留给她。</p><span class="tag">日常 · 叶瑄</span></div></article><article class="entry"><div class="day">08<small>THURSDAY</small></div><div><h2>雨停之后</h2><p>我们聊起很久以前的一场雨。窗外的树叶被洗得很干净，像一个温柔的新开始。</p><span class="tag">小小的回忆</span></div></article><article class="entry"><div class="day">06<small>TUESDAY</small></div><div><h2>慢一点，也没有关系</h2><p>花园里的小芽又长高了一点。我们也是。</p></div></article>`;
 if(page==='garden')view.innerHTML=`${intro('一起，慢慢生长。','有些美好，值得花一点时间。','OUR SECRET GARDEN')}<div class="scene dream-scene">${landscape(true)}</div><div class="card"><div class="eyebrow">在我们的花园里</div><h2>一株小小的洋桔梗</h2><p>叶片舒展开了，新的花苞正在悄悄酝酿。</p><div class="stats"><div><strong>12</strong><small>陪伴天数</small></div><div><strong>03</strong><small>新生叶片</small></div><div><strong>晴</strong><small>今日天气</small></div></div></div><p class="section-label">「不用催促它，它会按自己的节奏开花。」</p>`;
 if(page==='settings')view.innerHTML=`${intro('舒适，由你定义。','把这里，变成你喜欢的样子。','MAKE YOURSELF AT HOME')}<div class="card"><div class="avatar">Me</div><h2>我和我的小世界</h2><p>今天也请好好照顾自己。</p></div><div class="section-label">外观</div><div class="row"><span>当前视觉方向<small>这里展示配色与控件样式</small></span><strong>${config[1]}</strong></div><div class="row"><span>轻柔动效</span><button class="switch" role="switch" aria-label="轻柔动效示范" aria-checked="true"></button></div><div class="section-label">系统设置 · 演示</div><div class="row"><span>消息提示<small>只体验控件，不更改手机设置</small></span><button class="switch" role="switch" aria-label="消息提示示范" aria-checked="true"></button></div><div class="section-label">能力检查 · 只读示例</div><div class="row"><span>通知权限</span><span>未检测</span></div><div class="row"><span>后端连接</span><span>未连接</span></div>`;
 if(page==='dream')view.innerHTML=`${intro('今晚，去往哪里？','闭上眼睛，故事才刚刚开始。','A PLACE BEYOND THE DAY')}<div class="scene dream-scene">${landscape()}</div><p class="dream-copy">月光落在远处的山脊。<br>他放慢脚步，回过头等你。<br>「走吧，前面还有很长的风景。」</p><button class="wide" data-page="chat">回到我们的对话</button>`;
 applyLayout(page);
 view.scrollTop=0;
}
function toast(message){const box=document.querySelector('.toast');clearTimeout(toastTimer);box.textContent=message;box.hidden=false;toastTimer=setTimeout(()=>box.hidden=true,2400);}
app.addEventListener('click',e=>{
 const button=e.target.closest('button');if(!button)return;
 if(button.dataset.page)render(button.dataset.page);
 if(button.dataset.prompt){document.querySelector('input').value=button.dataset.prompt;document.querySelector('input').focus();}
 if(button.matches('.switch')){button.setAttribute('aria-checked',button.getAttribute('aria-checked')!=='true');toast('仅演示控件状态，不会保存');}
});
document.querySelector('#dream').addEventListener('click',()=>render('dream'));
document.querySelector('#attach').addEventListener('click',()=>toast('这里可放图片、文件与语音入口（视觉示范）'));
document.querySelector('form').addEventListener('submit',e=>{
 e.preventDefault();const input=document.querySelector('input');const value=input.value.trim();if(!value)return;
 const group=document.querySelector('#new-messages');
 const mine=document.createElement('div');mine.className='message mine';const bubble=document.createElement('div');bubble.className='bubble';bubble.textContent=value;mine.append(bubble);group.append(mine);
 const reply=document.createElement('div');reply.className='message';reply.innerHTML='<span class="by">演示回复</span><div class="bubble">我在，慢慢说就好。<br>（这是本地示范，不会发送给模型。）</div>';group.append(reply);input.value='';view.scrollTop=view.scrollHeight;
});
setupLayout();
render(style==='peach'?'home':'chat');
