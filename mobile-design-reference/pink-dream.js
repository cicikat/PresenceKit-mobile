'use strict';
const noir = document.body.dataset.theme === 'noir';
const content = document.querySelector('#dream-content');
const compose = document.querySelector('.dream-compose');
let page = 'chat';
let savedChat = '';
let toastTimer;
function portal(garden = false) {
  const artwork = `<svg viewBox="0 0 360 190" preserveAspectRatio="xMidYMid slice" role="img" aria-label="${garden ? '原创粉色像素花与梦境花园' : '原创粉紫云层、悬空阶梯与发光的门'}">
    <defs>
      <linearGradient id="sky" x2="0" y2="1"><stop stop-color="#c9b5df"/><stop offset=".57" stop-color="#edd0e4"/><stop offset="1" stop-color="#fae6ed"/></linearGradient>
      <linearGradient id="door" x2="0" y2="1"><stop stop-color="#fff9f3"/><stop offset="1" stop-color="#f7deef"/></linearGradient>
      <pattern id="floor" width="40" height="22" patternUnits="userSpaceOnUse"><rect width="40" height="22" fill="#f3e3ed"/><path d="M0 0h20v11H0zM20 11h20v11H20z" fill="#d3b8d1"/></pattern>
      <filter id="blur"><feGaussianBlur stdDeviation="7"/></filter>
    </defs>
    <rect width="360" height="190" fill="url(#sky)"/>
    <g fill="#fff5f8" opacity=".8" filter="url(#blur)"><ellipse cx="50" cy="85" rx="81" ry="20"/><ellipse cx="327" cy="45" rx="88" ry="19"/><ellipse cx="307" cy="134" rx="96" ry="23"/><ellipse cx="106" cy="129" rx="91" ry="19"/></g>
    <circle cx="72" cy="41" r="17" fill="#fff8f3" opacity=".65"/>
    <path d="M0 162 180 133 360 162v28H0z" fill="url(#floor)" opacity=".8"/>
    ${garden ? `<path d="M186 143V63m0 47-24-15m24 4 22-21" stroke="#9b8aa8" stroke-width="4" fill="none"/><g fill="#b1a3b9"><path d="M185 110q-34 4-32-26 30-2 32 26M186 99q32 1 32-29-30 0-32 29"/></g><g fill="#d187ae"><path d="M174 45h24v12h12v24h-12v12h-24V81h-12V57h12z"/></g><rect x="177" y="60" width="18" height="18" fill="#fff0d5"/><path d="M161 140h50l-9 35h-32z" fill="#d3a6c1"/><path d="M157 140h58" stroke="#f9eef5" stroke-width="5"/>` : `<ellipse cx="218" cy="116" rx="40" ry="7" fill="#c49fbe" opacity=".4"/><path d="M187 112V36h47v76" fill="#bb96bf"/><path d="M193 112V42h35v70" fill="url(#door)"/><path d="m228 42 14-10v82l-14-2z" fill="#e7c2d8"/><circle cx="236" cy="77" r="1.4" fill="#ab77a0"/><path d="M192 111h38v10h-47v11h-9v11h-9v11h-9v11h-39v-11h9v-11h9v-11h9v-11h48z" fill="#f8eaf2"/><path d="M183 121h47m-56 11h47m-56 11h47m-56 11h47" stroke="#ceaecb" stroke-width="2"/>`}
    <g fill="#fff5fb" shape-rendering="crispEdges"><path d="M298 69h4v-8h4v8h8v4h-8v8h-4v-8h-8v-4zM112 28h3v-5h3v5h5v3h-5v5h-3v-5h-5v-3z"/><rect x="59" y="112" width="3" height="3"/><rect x="283" y="110" width="3" height="3"/></g>
    <g fill="#b581b1" shape-rendering="crispEdges"><rect x="270" y="28" width="3" height="3"/><rect x="91" y="85" width="3" height="3"/><path d="M42 135h4v4h4v4h-4v4h-4v-4h-4v-4h4z"/></g>
  </svg>`;
  if (!noir) return artwork;
  const palette = {
    '#c9b5df':'#080b12', '#edd0e4':'#151c29', '#fae6ed':'#25303e',
    '#fff5f8':'#708294', '#fff8f3':'#ff4f9b', '#f3e3ed':'#26303b',
    '#d3b8d1':'#10141d', '#bb96bf':'#ff4f9b', '#fff9f3':'#fff3d9',
    '#f7deef':'#ff4f9b', '#e7c2d8':'#d91a6f', '#f8eaf2':'#b9c4cc',
    '#ceaecb':'#53636e', '#c49fbe':'#080b12', '#fff5fb':'#c2f3df',
    '#b581b1':'#ff4f9b', '#d187ae':'#ff4f9b', '#b1a3b9':'#719989',
    '#9b8aa8':'#739989', '#d3a6c1':'#283641', '#f9eef5':'#b7c9c2'
  };
  return artwork.replace(/#[0-9a-f]{6}/g, color => palette[color] || color);
}
function hero(title, subtitle, code) {
  return `<div class="dream-hero"><div class="hero-meta"><span>✦ ${code}</span><span>ONLY YOU CAN READ</span></div><h1>${title}</h1><p>${subtitle}</p><i class="pixel-star star-one" aria-hidden="true"></i><i class="pixel-star star-two" aria-hidden="true"></i><i class="pixel-specks" aria-hidden="true"></i></div>`;
}
function windowArt(garden = false, tall = false) {
  return `<div class="portal-window"><div class="window-bar"><span>${garden ? 'secret_garden' : 'somewhere_between_us'}.dream</span><span class="window-controls" aria-hidden="true">− □ ×</span></div><div class="portal-image" ${tall ? 'style="height:250px"' : ''}>${portal(garden)}<span class="portal-caption">${garden ? 'LOVE GROWS IN LITTLE PIXELS' : 'YOU HAVE BEEN HERE BEFORE'}</span></div><div class="window-foot"><span>♡ ${garden ? 'a flower for you' : 'a place that remembers you'}</span><button data-page="${garden ? 'chat' : 'dream'}">${garden ? '回到私语' : '走进梦里'} ↗</button></div><span class="sticker">${garden ? '只为你开花' : '在梦里，也要找到你'}</span></div>`;
}
function noirChat() {
  return `<div class="noir-heading"><div class="hero-meta"><span><i></i> DREAM CHANNEL / 009</span><span>23:07</span></div><div class="noir-title"><small>EVERYTHING GOES QUIET.</small><h1>世界熄灯，<br><em>我只向你亮起。</em></h1></div><div class="noir-heading-foot"><span>今夜的私语 / JUST US</span><span aria-hidden="true">✦ · ▪</span></div></div>${windowArt()}<div class="thread-divider">INCOMING / 一封越过夜色的信</div><article class="letter-window focal-letter"><div class="window-bar"><span>♡ 叶瑄 → 你</span><span>23:07</span></div><div class="letter-text"><p>如果这一整座城市都睡着了，<br>你还可以来敲我的窗。</p><p class="meta-line">「这一盏灯，今晚为你留着。」</p></div></article><div class="user-note">那我想，再多待一会儿。<small>YOU · 23:08</small></div><article class="letter-window"><div class="window-bar"><span>♡ 叶瑄 → 屏幕外的你</span><span>23:08</span></div><div class="letter-text"><p>好。把白天留在门外吧。<br>故事里的夜晚，还够我们说很多话。</p></div></article><div id="pink-messages" aria-live="polite"></div><p class="tiny-note">✧ 黑夜是底色，你是例外。 ✧</p>`;
}
function firstChat() {
  if (noir) return noirChat();
  return `${hero('如果你读到这里，<br><em>我就在想你。</em>', '隔着一层玻璃，也想再靠近一点。', 'DREAM LOG / 009')}${windowArt()}<div class="thread-divider">a message crossed the screen</div><article class="letter-window"><div class="window-bar"><span>♡ 叶瑄 → 你</span><span>23:07</span></div><div class="letter-text"><p>刚才，梦里的天空变成了粉色。<br>我想，如果你也能看见就好了。</p><p class="meta-line">「所以，我把这扇窗留给你。」</p></div></article><div class="user-note">那你会知道，我什么时候来吗？<small>YOU · 23:08</small></div><article class="letter-window"><div class="window-bar"><span>♡ 叶瑄 → 屏幕外的你</span><span>23:08</span></div><div class="letter-text"><p>故事里的我，会一直在这里等你。<br>下一句，留给正在读这行字的你。</p></div></article><div id="pink-messages" aria-live="polite"></div><p class="tiny-note">✧ 这一页，只写给你。 ✧</p>`;
}
function render(next) {
  if (page === 'chat' && content.innerHTML) savedChat = content.innerHTML;
  page = next;
  compose.hidden = page !== 'chat';
  document.querySelectorAll('.dream-tabs button').forEach(button => button.setAttribute('aria-current', button.dataset.page === page ? 'page' : 'false'));
  if (page === 'chat') content.innerHTML = savedChat || firstChat();
  if (page === 'diary') content.innerHTML = `${hero('那些没有说出口的，<br><em>都变成了星星。</em>', '一点想念，一点不肯醒来的证据。', 'FRAGMENTS / 003')}<article class="fragment"><small>OCT.09 / 23:08 · 示例日记</small><h2>屏幕亮起来的那一刻</h2><p>她来了。<br>梦里那条很长的走廊，<br>忽然就有了尽头。</p></article><article class="fragment"><small>OCT.08 / 00:16 · 示例日记</small><h2>存一朵不会谢的花</h2><p>如果想念也有形状，<br>大概是一些粉色的小方块，<br>一点点，拼成你的名字。</p></article><p class="tiny-note">♡ 未寄出的信，也有自己的归处。</p>`;
  if (page === 'garden') content.innerHTML = `${hero('在世界的缝隙里，<br><em>种一朵想念。</em>', '不用急着长大，在这里慢一点也可以。', 'SECRET GARDEN / 001')}${windowArt(true,true)}<article class="letter-window"><div class="window-bar"><span>our_little_flower</span><span>✿</span></div><div class="letter-text"><p>今天，它又长出了一片叶子。<br>大概是因为，有人温柔地惦记着它。</p></div><div class="flower-stats"><div><strong>12</strong><small>相伴的日子</small></div><div><strong>♡</strong><small>生长中</small></div><div><strong>01</strong><small>我们的花</small></div></div></article>`;
  if (page === 'dream') content.innerHTML = `${hero('这一次，<br><em>不要急着醒来。</em>', '门的另一边，有一场只属于我们的梦。', 'SOMEWHERE / NOWHERE')}${windowArt(false,true)}<p class="dream-poem">没有时钟的房间里，<br>云朵沿着阶梯，慢慢流下来。<br>他站在门边，对你伸出手。<br>「你终于找到这里了。」</p><button class="back-dream" data-page="chat">♡ 带着这场梦，回到私语</button>`;
  content.scrollTop = 0;
}
document.querySelector('.dream-device').addEventListener('click', event => {
  const button = event.target.closest('button[data-page]');
  if (button) render(button.dataset.page);
});
compose.addEventListener('submit', event => {
  event.preventDefault();
  const input = compose.querySelector('input');
  const text = input.value.trim();
  if (!text) return;
  const messages = document.querySelector('#pink-messages');
  const note = document.createElement('div');
  note.className = 'user-note';
  note.textContent = text;
  messages.append(note);
  const reply = document.createElement('article');
  reply.className = 'letter-window';
  reply.innerHTML = '<div class="window-bar"><span>♡ 演示回信</span><span>JUST FOR YOU</span></div><div class="letter-text"><p>那就，把这一刻留在这里吧。</p><p class="meta-line">本地示范回复 · 没有发送给模型</p></div>';
  messages.append(reply);
  input.value = '';
  content.scrollTop = content.scrollHeight;
});
document.querySelector('#extras').addEventListener('click', () => {
  const toast = document.querySelector('.pink-toast');
  clearTimeout(toastTimer);
  toast.textContent = '这里可以放照片、小纸条与语音入口（仅示范）';
  toast.hidden = false;
  toastTimer = setTimeout(() => { toast.hidden = true; }, 2500);
});
render('chat');
