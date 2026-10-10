const {chromium}=require(process.env.PLAYWRIGHT_MODULE || 'playwright');
const fs=require('node:fs');
const path=require('node:path');
(async()=>{
 const browser=await chromium.launch({channel:'chrome',headless:true,args:['--use-angle=swiftshader','--enable-webgl','--enable-unsafe-swiftshader']});
 const page=await browser.newPage({viewport:{width:390,height:844},deviceScaleFactor:1});
 const errors=[];page.on('pageerror',e=>errors.push(e.message));
 const requests=[];page.on('request',r=>{if(!r.url().startsWith('http://127.0.0.1:8766/'))requests.push(r.url());});
 const results=[];fs.mkdirSync(path.join(__dirname,'evidence'),{recursive:true});
 for(const id of ['c1','c2','c3','c4','f1','f2','f3','f4']){
  await page.goto('http://127.0.0.1:8766/directions/design.html?id='+id+'&static=1');
  await page.waitForFunction(()=>document.querySelector('#scene').dataset.renderer==='webgl2');
  await page.screenshot({path:path.join(__dirname,'evidence',id+'.png')});
  const widths=[];
  for(const width of [320,390,430]){await page.setViewportSize({width,height:844});widths.push(await page.evaluate(()=>({width:innerWidth,overflow:document.documentElement.scrollWidth>innerWidth,composerVisible:document.querySelector('#composer').getBoundingClientRect().bottom<=innerHeight,chatWidth:document.querySelector('.conversation').clientWidth})));}
  await page.setViewportSize({width:390,height:844});
  await page.locator('.composer input').fill('<hello> 梦里的海');await page.locator('#composer').evaluate(el=>el.requestSubmit());
  const textSafe=await page.locator('#messages article:last-child p').textContent()==='<hello> 梦里的海';
  await page.locator('#prompt').click();const prompt=await page.locator('.composer input').inputValue();
  await page.locator('#settings').click();await page.locator('#reset').click();const reset=await page.locator('#messages article').count()===3;
  const before=await page.locator('#scene').getAttribute('data-time');await page.locator('#motion').click();await page.waitForTimeout(250);const after=await page.locator('#scene').getAttribute('data-time');await page.locator('#motion').click();const stopped=await page.locator('#scene').getAttribute('data-time');await page.waitForTimeout(120);const paused=stopped===await page.locator('#scene').getAttribute('data-time');
  await page.locator('#controls form button').click();
  let fragment=null;if(await page.locator('#fragment').count()){await page.locator('#fragment').click();await page.locator('#use-fragment').click();fragment=(await page.locator('.composer input').inputValue()).includes('车站');}
  results.push({id,widths,textSafe,prompt:!!prompt,reset,moves:before!==after,paused,fragment});
 }
 await page.emulateMedia({reducedMotion:'reduce'});await page.goto('http://127.0.0.1:8766/directions/design.html?id=f2');await page.waitForFunction(()=>document.querySelector('#scene').dataset.renderer==='webgl2');const reducedTime=await page.locator('#scene').getAttribute('data-time');await page.waitForTimeout(250);const reducedFrozen=reducedTime===await page.locator('#scene').getAttribute('data-time');
 await page.setViewportSize({width:1440,height:1100});await page.goto('http://127.0.0.1:8766/directions/index.html');const cards=await page.locator('.card').count();await page.screenshot({path:path.join(__dirname,'evidence','overview.png'),fullPage:true});
 await page.addInitScript(()=>{HTMLCanvasElement.prototype.getContext=()=>null;});await page.goto('http://127.0.0.1:8766/directions/design.html?id=c1');const fallback=await page.locator('#failure').isVisible();
 const report={results,errors,externalRequests:requests,reducedFrozen,overviewCards:cards,fallback,device:'not-run: mobile GPU, Safari, keyboard, power'};
 fs.writeFileSync(path.join(__dirname,'validation.json'),JSON.stringify(report,null,2)+'\r\n');console.log(JSON.stringify(report));await browser.close();
 if(errors.length||requests.length||cards!==8||!reducedFrozen||!fallback||results.some(r=>!r.textSafe||!r.reset||!r.moves||!r.paused||r.widths.some(w=>w.overflow||!w.composerVisible)))process.exitCode=1;
})().catch(e=>{console.error(e);process.exitCode=1;});
