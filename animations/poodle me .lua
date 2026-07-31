<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="UTF-8" />
  <meta name="viewport" content="width=device-width, initial-scale=1.0" />

  <title>yourscoper</title>
  <meta name="description" content="Universal Script・Made by yourscoper" />

  <meta property="og:title" content="yourscoper" />
  <meta property="og:description" content="Universal Script・Made by yourscoper" />
  <meta property="og:type" content="website" />
  <meta property="og:url" content="https://yourscoper.pages.dev/" />
  <meta property="og:image" content="https://yourscoper.pages.dev/theweeknd.jpg" />
  <meta property="og:image:width" content="160" />
  <meta property="og:image:height" content="160" />
  <meta property="og:image:type" content="image/jpeg" />

  <meta name="twitter:card" content="summary" />
  <meta name="twitter:title" content="yourscoper" />
  <meta name="twitter:description" content="Universal Script・Made by yourscoper" />
  <meta name="twitter:image" content="https://yourscoper.pages.dev/theweeknd.jpg" />
  
  <meta name="theme-color" content="#ffffff" />
  <link rel="icon" href="https://yourscoper.pages.dev/theweeknd.jpg" type="image/jpeg" />
  <link href="https://fonts.googleapis.com/css2?family=JetBrains+Mono:wght@400;700&family=Inter:wght@300;400;600&display=swap" rel="stylesheet">
  
  <script
    disable-devtool-auto
    src="https://cdn.jsdelivr.net/npm/disable-devtool"
    url="https://theajack.github.io/disable-devtool/404.html?h=yourscoper.pages.dev">
  </script>
</head>

  <style>
    *, *::before, *::after { margin: 0; padding: 0; box-sizing: border-box; }

    :root {
      --bg: #050505;
      --surface: #0d0d0d;
      --border: rgba(255,255,255,0.07);
      --accent: #a78bfa;
      --accent2: #38bdf8;
      --text: #e2e8f0;
      --muted: #64748b;
      --code-bg: #0a0a0f;
    }

    html, body {
      height: 100%;
      background: var(--bg);
      color: var(--text);
      font-family: 'Inter', sans-serif;
      overflow-x: hidden;
    }

    #bg-canvas {
      position: fixed;
      inset: 0;
      z-index: 0;
      pointer-events: none;
    }

    .page {
      position: relative;
      z-index: 1;
      min-height: 100vh;
      display: flex;
      flex-direction: column;
      align-items: center;
      justify-content: center;
      padding: 60px 24px;
    }

    .eyebrow {
      font-family: 'JetBrains Mono', monospace;
      font-size: 11px;
      letter-spacing: 0.2em;
      text-transform: uppercase;
      color: var(--accent);
      margin-bottom: 20px;
      opacity: 0;
      animation: fadeUp 0.6s ease 0.2s forwards;
    }

    h1 {
      font-family: 'JetBrains Mono', monospace;
      font-size: clamp(2.8rem, 7vw, 5.5rem);
      font-weight: 700;
      line-height: 1;
      letter-spacing: -0.03em;
      text-align: center;
      margin-bottom: 18px;
      opacity: 0;
      animation: fadeUp 0.6s ease 0.35s forwards;
    }

    h1 .grad {
      background: linear-gradient(135deg, #fff 30%, var(--accent) 70%, var(--accent2) 100%);
      -webkit-background-clip: text;
      -webkit-text-fill-color: transparent;
      background-clip: text;
    }

    .sub {
      font-size: 16px;
      color: var(--muted);
      text-align: center;
      max-width: 460px;
      line-height: 1.6;
      margin-bottom: 48px;
      opacity: 0;
      animation: fadeUp 0.6s ease 0.5s forwards;
    }

    .script-card {
      width: 100%;
      max-width: 700px;
      background: var(--code-bg);
      border: 1px solid var(--border);
      border-radius: 16px;
      overflow: hidden;
      box-shadow: 0 0 0 1px rgba(167,139,250,0.08), 0 40px 80px rgba(0,0,0,0.6);
      opacity: 0;
      animation: fadeUp 0.6s ease 0.65s forwards;
      position: relative;
    }

    .card-header {
      display: flex;
      align-items: center;
      justify-content: space-between;
      padding: 14px 20px;
      border-bottom: 1px solid var(--border);
      background: rgba(255,255,255,0.02);
    }

    .dots {
      display: flex;
      gap: 7px;
    }

    .dots span {
      width: 12px;
      height: 12px;
      border-radius: 50%;
    }

    .dots span:nth-child(1) { background: #ff5f57; }
    .dots span:nth-child(2) { background: #febc2e; }
    .dots span:nth-child(3) { background: #28c840; }

    .card-label {
      font-family: 'JetBrains Mono', monospace;
      font-size: 12px;
      color: var(--muted);
    }

    .copy-btn {
      display: flex;
      align-items: center;
      gap: 7px;
      background: rgba(167,139,250,0.1);
      border: 1px solid rgba(167,139,250,0.25);
      border-radius: 8px;
      padding: 6px 14px;
      color: var(--accent);
      font-family: 'JetBrains Mono', monospace;
      font-size: 12px;
      cursor: pointer;
      transition: all 0.2s;
    }

    .copy-btn:hover {
      background: rgba(167,139,250,0.2);
      transform: scale(1.03);
    }

    .copy-btn.copied {
      background: rgba(56,189,248,0.15);
      border-color: rgba(56,189,248,0.3);
      color: var(--accent2);
    }

    .copy-btn svg { width: 14px; height: 14px; fill: currentColor; }

    .code-block {
      padding: 28px 28px;
      font-family: 'JetBrains Mono', monospace;
      font-size: 14px;
      line-height: 1.8;
      /* removed overflow-x: auto to eliminate scrollbar */
      position: relative;
    }

    .line-glow {
      display: block;
      white-space: pre-wrap;
      word-break: break-all;
    }

    .kw { color: #c792ea; }
    .fn { color: #82aaff; }
    .str { color: #c3e88d; }
    .call { color: var(--accent2); }
    .punc { color: var(--muted); }

    .glow-line {
      position: relative;
    }

    .glow-line::after {
      content: '';
      position: absolute;
      left: -28px;
      right: -28px;
      top: 0;
      bottom: 0;
      background: linear-gradient(90deg, transparent, rgba(167,139,250,0.04), transparent);
      pointer-events: none;
      opacity: 0;
      animation: scanline 4s ease-in-out infinite;
    }

    @keyframes scanline {
      0%, 100% { opacity: 0; transform: translateY(0); }
      50% { opacity: 1; }
    }

    /* Key card */
    .key-card {
      width: 100%;
      max-width: 700px;
      background: var(--code-bg);
      border: 1px solid var(--border);
      border-radius: 16px;
      overflow: hidden;
      box-shadow: 0 0 0 1px rgba(56,189,248,0.06), 0 20px 50px rgba(0,0,0,0.4);
      margin-top: 16px;
      opacity: 0;
      animation: fadeUp 0.6s ease 0.75s forwards;
    }

    .key-header {
      display: flex;
      align-items: center;
      justify-content: space-between;
      padding: 12px 20px;
      border-bottom: 1px solid var(--border);
      background: rgba(255,255,255,0.02);
    }

    .key-badge {
      display: flex;
      align-items: center;
      gap: 7px;
      font-family: 'JetBrains Mono', monospace;
      font-size: 11px;
      letter-spacing: 0.08em;
      color: var(--accent2);
    }

    .key-badge .badge-dot {
      width: 6px;
      height: 6px;
      border-radius: 50%;
      background: var(--accent2);
      box-shadow: 0 0 8px var(--accent2);
    }

    .key-label {
      font-family: 'JetBrains Mono', monospace;
      font-size: 11px;
      color: var(--muted);
      letter-spacing: 0.05em;
    }

    .copy-btn-key {
      display: flex;
      align-items: center;
      gap: 7px;
      background: rgba(56,189,248,0.08);
      border: 1px solid rgba(56,189,248,0.2);
      border-radius: 8px;
      padding: 6px 14px;
      color: var(--accent2);
      font-family: 'JetBrains Mono', monospace;
      font-size: 12px;
      cursor: pointer;
      transition: all 0.2s;
    }

    .copy-btn-key:hover {
      background: rgba(56,189,248,0.16);
      transform: scale(1.03);
    }

    .copy-btn-key.copied {
      background: rgba(167,139,250,0.12);
      border-color: rgba(167,139,250,0.3);
      color: var(--accent);
    }

    .copy-btn-key svg { width: 14px; height: 14px; fill: currentColor; }

    .key-block {
      padding: 22px 28px;
      font-family: 'JetBrains Mono', monospace;
      font-size: 13px;
      line-height: 1.8;
      color: var(--accent2);
      letter-spacing: 0.03em;
      word-break: break-all;
    }

    .features {
      display: flex;
      gap: 16px;
      margin-top: 36px;
      flex-wrap: wrap;
      justify-content: center;
      opacity: 0;
      animation: fadeUp 0.6s ease 0.9s forwards;
    }

    .feat {
      display: flex;
      align-items: center;
      gap: 8px;
      background: rgba(255,255,255,0.03);
      border: 1px solid var(--border);
      border-radius: 10px;
      padding: 10px 16px;
      font-size: 13px;
      color: var(--muted);
    }

    .feat .dot {
      width: 6px;
      height: 6px;
      border-radius: 50%;
      background: var(--accent);
      box-shadow: 0 0 8px var(--accent);
      flex-shrink: 0;
    }

    .portfolio-link {
      margin-top: 48px;
      font-family: 'JetBrains Mono', monospace;
      font-size: 12px;
      color: var(--muted);
      text-decoration: none;
      letter-spacing: 0.05em;
      transition: color 0.2s;
      opacity: 0;
      animation: fadeUp 0.6s ease 1.1s forwards;
    }

    .portfolio-link:hover { color: var(--accent); }

    @keyframes fadeUp {
      from { opacity: 0; transform: translateY(20px); }
      to { opacity: 1; transform: translateY(0); }
    }

    .toast {
      position: fixed;
      bottom: 32px;
      left: 50%;
      transform: translateX(-50%) translateY(80px);
      background: rgba(167,139,250,0.15);
      border: 1px solid rgba(167,139,250,0.3);
      backdrop-filter: blur(12px);
      border-radius: 10px;
      padding: 12px 20px;
      font-family: 'JetBrains Mono', monospace;
      font-size: 13px;
      color: var(--accent);
      z-index: 100;
      transition: transform 0.4s cubic-bezier(0.34,1.56,0.64,1);
      pointer-events: none;
    }

    .toast.show {
      transform: translateX(-50%) translateY(0);
    }
  </style>
</head>
<body>
  <canvas id="bg-canvas"></canvas>

  <div class="page">
    <div class="eyebrow">— roblox executor script —</div>
    <h1><span class="grad">scoper's</span><br>commands</h1>
    <p class="sub">A powerful Roblox script. Paste the loadstring into your executor and run.</p>

    <div class="script-card">
      <div class="card-header">
        <div class="dots">
          <span></span><span></span><span></span>
        </div>
        <div class="card-label">loadstring.lua</div>
        <button class="copy-btn" id="copyBtn">
          <svg viewBox="0 0 24 24"><path d="M16 1H4c-1.1 0-2 .9-2 2v14h2V3h12V1zm3 4H8c-1.1 0-2 .9-2 2v14c0 1.1.9 2 2 2h11c1.1 0 2-.9 2-2V7c0-1.1-.9-2-2-2zm0 16H8V7h11v14z"/></svg>
          copy
        </button>
      </div>
      <div class="code-block glow-line">
        <span class="line-glow"><span class="fn">loadstring</span><span class="punc">(</span><span class="fn">game</span><span class="punc">:</span><span class="call">HttpGet</span><span class="punc">(</span><span class="str">"https://yourscoper.pages.dev/scoper.lua"</span><span class="punc">))();</span></span>
      </div>
    </div>

    <!-- Free user key card -->
    <div class="key-card">
      <div class="key-header">
        <div class="key-badge">
          <span class="badge-dot"></span>
          free key
        </div>
        <div class="key-label">key.txt</div>
        <button class="copy-btn-key" id="copyKeyBtn">
          <svg viewBox="0 0 24 24"><path d="M16 1H4c-1.1 0-2 .9-2 2v14h2V3h12V1zm3 4H8c-1.1 0-2 .9-2 2v14c0 1.1.9 2 2 2h11c1.1 0 2-.9 2-2V7c0-1.1-.9-2-2-2zm0 16H8V7h11v14z"/></svg>
          copy
        </button>
      </div>
      <div class="key-block">scoper-WNwzEGr9VAvrVF1KWfveWanA7CEIse</div>
    </div>

    <div class="features">
      <div class="feat"><span class="dot"></span>nametag system</div>
      <div class="feat"><span class="dot"></span>command gui</div>
      <div class="feat"><span class="dot"></span>animation library</div>
      <div class="feat"><span class="dot"></span>reanimation</div>
    </div>

    <a class="portfolio-link" href="/portfolio">view portfolio →</a>
  </div>

  <div class="toast" id="toast">copied to clipboard</div>

  <script>
    const canvas = document.getElementById('bg-canvas');
    const ctx = canvas.getContext('2d');
    let W, H, particles = [];

    function resize() {
      W = canvas.width = window.innerWidth;
      H = canvas.height = window.innerHeight;
    }
    resize();
    window.addEventListener('resize', resize);

    function randBetween(a, b) { return a + Math.random() * (b - a); }

    class Particle {
      constructor() { this.reset(); }
      reset() {
        this.x = Math.random() * W;
        this.y = Math.random() * H;
        this.vx = randBetween(-0.15, 0.15);
        this.vy = randBetween(-0.3, -0.05);
        this.size = randBetween(1, 2.5);
        this.alpha = randBetween(0.1, 0.5);
        this.life = 0;
        this.maxLife = randBetween(200, 400);
        this.color = Math.random() > 0.5 ? '167,139,250' : '56,189,248';
      }
      update() {
        this.x += this.vx;
        this.y += this.vy;
        this.life++;
        if (this.life > this.maxLife || this.y < -10) this.reset();
      }
      draw() {
        const progress = this.life / this.maxLife;
        const a = this.alpha * Math.sin(progress * Math.PI);
        ctx.beginPath();
        ctx.arc(this.x, this.y, this.size, 0, Math.PI * 2);
        ctx.fillStyle = `rgba(${this.color},${a})`;
        ctx.fill();
      }
    }

    for (let i = 0; i < 120; i++) particles.push(new Particle());

    function drawConnections() {
      for (let i = 0; i < particles.length; i++) {
        for (let j = i + 1; j < particles.length; j++) {
          const dx = particles[i].x - particles[j].x;
          const dy = particles[i].y - particles[j].y;
          const dist = Math.sqrt(dx*dx + dy*dy);
          if (dist < 100) {
            const a = (1 - dist/100) * 0.06;
            ctx.beginPath();
            ctx.moveTo(particles[i].x, particles[i].y);
            ctx.lineTo(particles[j].x, particles[j].y);
            ctx.strokeStyle = `rgba(167,139,250,${a})`;
            ctx.lineWidth = 0.5;
            ctx.stroke();
          }
        }
      }
    }

    let mouseX = -1000, mouseY = -1000;
    document.addEventListener('mousemove', e => { mouseX = e.clientX; mouseY = e.clientY; });

    function drawOrb(x, y, r, color) {
      const g = ctx.createRadialGradient(x, y, 0, x, y, r);
      g.addColorStop(0, `rgba(${color},0.12)`);
      g.addColorStop(1, `rgba(${color},0)`);
      ctx.beginPath();
      ctx.arc(x, y, r, 0, Math.PI * 2);
      ctx.fillStyle = g;
      ctx.fill();
    }

    let frame = 0;
    function animate() {
      ctx.clearRect(0, 0, W, H);
      frame++;

      const ox1 = W * 0.2 + Math.sin(frame * 0.003) * 80;
      const oy1 = H * 0.3 + Math.cos(frame * 0.004) * 60;
      const ox2 = W * 0.8 + Math.sin(frame * 0.005 + 1) * 60;
      const oy2 = H * 0.7 + Math.cos(frame * 0.003 + 2) * 80;

      drawOrb(ox1, oy1, 340, '167,139,250');
      drawOrb(ox2, oy2, 300, '56,189,248');

      if (mouseX > 0) drawOrb(mouseX, mouseY, 180, '167,139,250');

      drawConnections();
      particles.forEach(p => { p.update(); p.draw(); });

      requestAnimationFrame(animate);
    }
    animate();

    // Loadstring copy
    const copyBtn = document.getElementById('copyBtn');
    const toast = document.getElementById('toast');
    const scriptText = `loadstring(game:HttpGet("https://yourscoper.pages.dev/scoper.lua"))();`;

    copyBtn.addEventListener('click', () => {
      navigator.clipboard.writeText(scriptText).then(() => {
        copyBtn.classList.add('copied');
        copyBtn.innerHTML = `<svg viewBox="0 0 24 24" style="fill:currentColor;width:14px;height:14px"><path d="M9 16.17L4.83 12l-1.42 1.41L9 19 21 7l-1.41-1.41z"/></svg> copied`;
        toast.classList.add('show');
        setTimeout(() => {
          copyBtn.classList.remove('copied');
          copyBtn.innerHTML = `<svg viewBox="0 0 24 24" style="fill:currentColor;width:14px;height:14px"><path d="M16 1H4c-1.1 0-2 .9-2 2v14h2V3h12V1zm3 4H8c-1.1 0-2 .9-2 2v14c0 1.1.9 2 2 2h11c1.1 0 2-.9 2-2V7c0-1.1-.9-2-2-2zm0 16H8V7h11v14z"/></svg> copy`;
          toast.classList.remove('show');
        }, 2000);
      });
    });

    // Key copy
    const copyKeyBtn = document.getElementById('copyKeyBtn');
    const keyText = `scoper-WNwzEGr9VAvrVF1KWfveWanA7CEIse`;

    copyKeyBtn.addEventListener('click', () => {
      navigator.clipboard.writeText(keyText).then(() => {
        copyKeyBtn.classList.add('copied');
        copyKeyBtn.innerHTML = `<svg viewBox="0 0 24 24" style="fill:currentColor;width:14px;height:14px"><path d="M9 16.17L4.83 12l-1.42 1.41L9 19 21 7l-1.41-1.41z"/></svg> copied`;
        toast.classList.add('show');
        setTimeout(() => {
          copyKeyBtn.classList.remove('copied');
          copyKeyBtn.innerHTML = `<svg viewBox="0 0 24 24" style="fill:currentColor;width:14px;height:14px"><path d="M16 1H4c-1.1 0-2 .9-2 2v14h2V3h12V1zm3 4H8c-1.1 0-2 .9-2 2v14c0 1.1.9 2 2 2h11c1.1 0 2-.9 2-2V7c0-1.1-.9-2-2-2zm0 16H8V7h11v14z"/></svg> copy`;
          toast.classList.remove('show');
        }, 2000);
      });
    });
  </script>
</body>
</html>
