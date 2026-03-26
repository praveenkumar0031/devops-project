function show(id) {
    document.querySelectorAll('.section').forEach(s => s.style.display = 'none');
    document.getElementById(id).style.display = 'block';
    // Clear all game intervals
    clearInterval(gameInterval);
    clearInterval(blinkInterval);
}

let gameInterval, blinkInterval;

/* --- 1. DECRYPT DATA (Memory) --- */
let emojis = ["💾", "📡", "🛡️", "🔑", "💻", "🔌", "📟", "🔋"];
let mem = [], flip = [], lock = false;

function startMemory() {
    mem = [...emojis, ...emojis].sort(() => Math.random() - 0.5);
    flip = []; document.getElementById("moves").innerText = 0;
    let g = document.getElementById("memoryGrid"); g.innerHTML = "";
    mem.forEach((e, i) => {
        let d = document.createElement("div"); d.className = "card"; d.innerText = "?";
        d.onclick = () => {
            if (lock || flip.includes(i)) return;
            d.innerText = mem[i]; flip.push(i);
            if (flip.length === 2) {
                lock = true; let [a, b] = flip; let cards = document.querySelectorAll(".card");
                if (mem[a] === mem[b]) { cards[a].style.opacity = "0.2"; cards[b].style.opacity = "0.2"; flip = []; lock = false; }
                else { setTimeout(() => { cards[a].innerText = "?"; cards[b].innerText = "?"; flip = []; lock = false; }, 500); }
            }
        };
        g.appendChild(d);
    });
}

/* --- 2. QUERY BOT (Fixed Target) --- */
let targetCode = "";
const chars = "0123456789ABCDEF!@#$%";

function startQueryBot() {
    let timeLeft = 20;
    targetCode = Array.from({length:4}, () => chars[Math.floor(Math.random()*chars.length)]).join('');
    document.getElementById("targetWord").innerText = targetCode;
    
    let targetPos = Math.floor(Math.random() * 64);
    let staticData = Array.from({length:64}, (_, i) => i === targetPos ? targetCode : Array.from({length:4}, () => chars[Math.floor(Math.random()*chars.length)]).join(''));

    clearInterval(gameInterval);
    clearInterval(blinkInterval);

    gameInterval = setInterval(() => {
        timeLeft--;
        document.getElementById("hackTimer").innerText = timeLeft;
        if(timeLeft <= 0) { clearInterval(gameInterval); clearInterval(blinkInterval); alert("TRACE_DETECTION_FAIL"); }
    }, 1000);

    blinkInterval = setInterval(() => renderQueryGrid(staticData, targetPos), 150);
}

function renderQueryGrid(data, targetIdx) {
    const grid = document.getElementById("wordGrid");
    grid.innerHTML = "";
    data.forEach((val, i) => {
        let span = document.createElement("div");
        span.className = "grid-item";
        if(i === targetIdx) {
            span.innerText = targetCode;
            span.classList.add("target-style");
        } else {
            // Blinking effect for garbage data
            span.innerText = Math.random() > 0.5 ? val : "####";
            span.style.opacity = Math.random() > 0.8 ? "0.2" : "1";
        }
        span.onclick = () => {
            if(i === targetIdx) {
                clearInterval(gameInterval); clearInterval(blinkInterval);
                alert("ACCESS_GRANTED");
                show('menu');
            }
        };
        grid.appendChild(span);
    });
}

/* --- 3. CI/CD DEPLOY GAME --- */
let buildsInARow = 0;
let buildStatus = "IDLE"; // "PASS" or "FAIL"

function attemptDeploy() {
    const statusText = document.getElementById("pipeline-status");
    if (buildStatus === "PASS") {
        buildsInARow++;
        document.getElementById("deployCount").innerText = buildsInARow;
        if (buildsInARow >= 5) {
            clearInterval(gameInterval);
            alert("PRODUCTION_STABLE: MISSION_SUCCESS");
            show('menu');
        }
    } else {
        buildsInARow = 0;
        document.getElementById("deployCount").innerText = "0";
        alert("BUILD_BROKEN: REVERTING_COMMIT");
    }
}

function startCicd() {
    buildsInARow = 0;
    document.getElementById("deployCount").innerText = "0";
    clearInterval(gameInterval);
    
    gameInterval = setInterval(() => {
        const indicator = document.getElementById("build-indicator");
        const statusText = document.getElementById("pipeline-status");
        
        if (Math.random() > 0.6) {
            buildStatus = "PASS";
            indicator.style.background = "#00ff41";
            statusText.innerText = "SUCCESS";
            statusText.className = "status-pass";
        } else {
            buildStatus = "FAIL";
            indicator.style.background = "#ff0000";
            statusText.innerText = "FAILED";
            statusText.className = "status-fail";
        }
    }, 800); // Speed changes every 0.8s
}

// Update menu logic to trigger CI/CD start
const originalShow = show;
show = function(id) {
    originalShow(id);
    if(id === 'cicd') startCicd();
}

show('menu');