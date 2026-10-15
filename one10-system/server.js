// One 10 - small local server: shows the app, prints on 2 printers (via Windows), keeps a backup of sales
const http=require('http'),fs=require('fs'),path=require('path'),os=require('os'),{execFile}=require('child_process');
const dir=__dirname,CFG=JSON.parse(fs.readFileSync(path.join(dir,'config.json'),'utf8'));
const APP=path.join(dir,'one10-pos.html'),BK=path.join(dir,'sales-backup.json'),PS=path.join(dir,'print.ps1');
const run=(args)=>new Promise((ok,no)=>execFile('powershell.exe',['-NoProfile','-ExecutionPolicy','Bypass',...args],{windowsHide:true,timeout:30000},(e,so,se)=>e?no(new Error((se||e.message).trim().slice(0,300))):ok(so)));
async function printLines(printerName,lines){
  const f=path.join(os.tmpdir(),'o10_'+Date.now()+'_'+Math.random().toString(36).slice(2)+'.json');
  fs.writeFileSync(f,JSON.stringify(lines),'utf8');
  try{await run(['-File',PS,'-Printer',printerName,'-Data',f]);}finally{fs.unlink(f,()=>{});}
}
async function update(){
  if(!CFG.updateUrl)return;
  try{const r=await fetch(CFG.updateUrl),t=await r.text();
    if(r.ok&&t.length>5000&&t.includes('<html')){fs.copyFileSync(APP,APP+'.bak');fs.writeFileSync(APP,t);console.log('App updated.');}
  }catch(e){console.log('No update (offline?)');}
}
http.createServer((req,res)=>{
  let body='';req.on('data',d=>body+=d);
  req.on('end',async()=>{
    try{
      if(req.method==='POST'&&req.url==='/print'){
        const j=JSON.parse(body),name=j.printer==='kitchen'?CFG.kitchenPrinter:CFG.customerPrinter;
        await printLines(name,j.lines);res.writeHead(200);return res.end('ok');
      }
      if(req.url==='/printers'){
        const o=await run(['-Command','Get-Printer | Select-Object -ExpandProperty Name']);
        res.writeHead(200,{'Content-Type':'application/json'});
        return res.end(JSON.stringify({customer:CFG.customerPrinter,kitchen:CFG.kitchenPrinter,installed:o.split(/\r?\n/).filter(Boolean)}));
      }
      if(req.url==='/backup'){
        if(req.method==='POST'){fs.writeFileSync(BK,body);res.writeHead(200);return res.end('ok');}
        res.writeHead(200,{'Content-Type':'application/json'});return res.end(fs.existsSync(BK)?fs.readFileSync(BK):'null');
      }
      res.writeHead(200,{'Content-Type':'text/html; charset=utf-8'});res.end(fs.readFileSync(APP));
    }catch(e){res.writeHead(500);res.end(e.message);}
  });
}).listen(CFG.port,async()=>{await update();console.log('One 10 is running: http://localhost:'+CFG.port+'  (keep this window open)');});
