function show(id){
document.querySelectorAll('.section').forEach(s=>s.style.display='none');
document.getElementById(id).style.display='block';
}

/* MEMORY */
let emojis=["🐶","🐱","🚗","🍎","⚽","🎮","🐼","🍕"];
let mem=[],flip=[],moves=0,lock=false;

function startMemory(){
mem=[...emojis,...emojis].sort(()=>Math.random()-0.5);
moves=0;flip=[];
document.getElementById("moves").innerText=0;
drawMem();
}

function drawMem(){
let g=document.getElementById("memoryGrid");
g.innerHTML="";
mem.forEach((e,i)=>{
let d=document.createElement("div");
d.className="card";
d.innerText="?";
d.onclick=()=>flipCard(d,i);
g.appendChild(d);
});
}

function flipCard(el,i){
if(lock||flip.includes(i))return;
el.innerText=mem[i];
el.classList.add("flipped");
flip.push(i);

if(flip.length==2){
moves++;
document.getElementById("moves").innerText=moves;

let [a,b]=flip;
if(mem[a]==mem[b]){
setTimeout(()=>{
document.querySelectorAll(".card")[a].classList.add("matched");
document.querySelectorAll(".card")[b].classList.add("matched");
flip=[];
checkWin();
},300);
}else{
lock=true;
setTimeout(()=>{
document.querySelectorAll(".card")[a].innerText="?";
document.querySelectorAll(".card")[b].innerText="?";
flip=[];lock=false;
},600);
}
}
}

function checkWin(){
if(document.querySelectorAll(".matched").length==mem.length){
let best=localStorage.getItem("best")||999;
if(moves<best){localStorage.setItem("best",moves);}
document.getElementById("best").innerText=localStorage.getItem("best");
alert("You Won!");
}
}

/* REACTION */
let startT,ready=false,seconds=0,interval;

function updateTimer(){
let h=Math.floor(seconds/3600);
let m=Math.floor((seconds%3600)/60);
let s=seconds%60;

document.getElementById("timer").innerText =
String(h).padStart(2,'0')+":"+
String(m).padStart(2,'0')+":"+
String(s).padStart(2,'0');
}

function resetLights(){
for(let i=1;i<=6;i++){
let el=document.getElementById("l"+i);
el.classList.remove("active","green");
}
}

function startReaction(){
resetLights();
seconds=0;
updateTimer();

if(interval) clearInterval(interval);
interval=setInterval(()=>{seconds++;updateTimer();},1000);

for(let i=1;i<=6;i++){
setTimeout(()=>{
document.getElementById("l"+i).classList.add("active");
},i*500);
}

let randomDelay = Math.random()*5000;

setTimeout(()=>{
for(let i=1;i<=6;i++){
let el=document.getElementById("l"+i);
el.classList.remove("active");
el.classList.add("green");
}
startT=new Date().getTime();
ready=true;
},3000 + randomDelay);
}

document.body.onclick=function(){
if(!ready)return;

let reaction=new Date().getTime()-startT;
document.getElementById("res").innerText=reaction;

let best=localStorage.getItem("bestR")||9999;
if(reaction<best){localStorage.setItem("bestR",reaction);}
document.getElementById("bestR").innerText=localStorage.getItem("bestR");

clearInterval(interval);
ready=false;
resetLights();
}

/* TRUTH */
let truths=["Secret?","Fear?","Crush?","Embarrassing moment?"];
let dares=["Dance!","Sing!","Pushups!","Act funny!"];
let spinning=false;

function spin(){
if(spinning)return;
spinning=true;

let wheel=document.getElementById("wheel");
let deg=Math.random()*360+720;
wheel.style.transform="rotate("+deg+"deg)";

setTimeout(()=>{
let angle=deg%360;

if(angle<180){
let t=truths[Math.floor(Math.random()*truths.length)];
document.getElementById("tdres").innerText="Truth: "+t;
}else{
let d=dares[Math.floor(Math.random()*dares.length)];
document.getElementById("tdres").innerText="Dare: "+d;
}

spinning=false;
},3000);
}