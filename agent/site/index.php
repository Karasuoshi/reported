<?php
$scheme = (!empty($_SERVER['HTTPS']) && $_SERVER['HTTPS'] !== 'off') || (isset($_SERVER['HTTP_X_FORWARDED_PROTO']) && $_SERVER['HTTP_X_FORWARDED_PROTO'] === 'https') ? 'https' : 'http';
$base = $scheme . '://' . (isset($_SERVER['HTTP_HOST']) ? $_SERVER['HTTP_HOST'] : 'localhost') . rtrim(dirname(isset($_SERVER['SCRIPT_NAME']) ? $_SERVER['SCRIPT_NAME'] : '/'), '/\\');
$base = htmlspecialchars($base, ENT_QUOTES, 'UTF-8');
?><!doctype html>
<html lang="ru">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width,initial-scale=1,viewport-fit=cover">
<title>Камень возвращения · &lt;Reported&gt;</title>
<meta name="description" content="Нажми на камень возвращения и запишись в ростер гильдии Reported. Старт WoW Forever — 5 ноября, 02:00 МСК.">
<meta name="theme-color" content="#060910">
<meta property="og:type" content="website">
<meta property="og:title" content="Камень возвращения · &lt;Reported&gt;">
<meta property="og:description" content="Жми на камень и записывайся в ростер. Старт WoW Forever — 5 ноября, 02:00 МСК.">
<meta property="og:image" content="<?= $base ?>/img/og.jpg">
<meta property="og:url" content="<?= $base ?>/">
<meta name="twitter:card" content="summary_large_image">
<link rel="icon" type="image/png" href="img/icon-64.png">
<link rel="apple-touch-icon" href="img/icon-180.png">
<link rel="preconnect" href="https://fonts.googleapis.com">
<link rel="preconnect" href="https://fonts.gstatic.com" crossorigin>
<link rel="stylesheet" href="https://fonts.googleapis.com/css2?family=Marcellus&family=Open+Sans:wght@400;600&family=Philosopher:wght@400;700&family=Unbounded:wght@600;800&family=Onest:wght@400;500;700&family=JetBrains+Mono:wght@400;600&display=swap">
<style>
@property --a{syntax:"<angle>"; inherits:false; initial-value:0deg}
:root{
  color-scheme: dark;
  --bg:#060910; --s1:#0e131b; --s2:#151b25; --s3:#1f2735;
  --line:rgba(200,225,255,.1); --line2:rgba(200,225,255,.2);
  --text:#f1ede4; --muted:#9ca6b5; --dim:#667080;
  --rune:#72e6ff; --ember:#ffb23f; --horde:#e0402f; --ally:#3d7bff; --bad:#ff5a5a; --ok:#46e06a;
  --np:#8080f8;
  --warrior:#c69b6d; --rogue:#fff468; --priest:#f4f4f4; --mage:#3fc7eb; --warlock:#9798f5; --hunter:#aad372; --druid:#ff7c0a; --shaman:#3d9bff; --paladin:#f48cba;
  --f-game:"Marcellus","Philosopher","Palatino Linotype",Georgia,serif;
  --f-disp:"Unbounded","Arial Black",Impact,sans-serif;
  --f-body:"Onest","Segoe UI",system-ui,-apple-system,sans-serif;
  --f-mono:"JetBrains Mono",ui-monospace,Consolas,monospace;
  --f-tip:"Open Sans","Segoe UI",Verdana,system-ui,sans-serif;
  --icon:clamp(150px,19vw,196px);
}
*{box-sizing:border-box}
img{max-width:100%}
[hidden]{display:none!important}
html,body{height:100%}
body{margin:0; color:var(--text); font:16px/1.55 var(--f-body); -webkit-font-smoothing:antialiased;
  background:
    radial-gradient(ellipse 42% 30% at 50% 0%, rgba(255,140,40,.13), rgba(255,140,40,0) 70%) fixed,
    radial-gradient(ellipse 80% 60% at 50% 48%, #10233b 0%, #0a121d 42%, var(--bg) 100%) fixed, var(--bg)}
button{font:inherit; color:inherit}
:focus-visible{outline:2px solid var(--rune); outline-offset:3px; border-radius:6px}
#sky{position:fixed; inset:0; width:100%; height:100%; z-index:0; pointer-events:none}

.page{position:relative; z-index:1; min-height:100%; display:grid; grid-template-rows:auto 1fr auto; padding-inline:16px; padding-block:calc(clamp(22px,4vh,44px) + env(safe-area-inset-top,0px)) calc(clamp(20px,4vh,36px) + env(safe-area-inset-bottom,0px)); text-align:center}

/* logo + nameplate как у персонажа */
.logo{display:grid; justify-items:center; gap:12px}
.logo h1{margin:0; line-height:0}
.moon{width:clamp(100px,15vw,144px); height:auto; animation:moonglow 7s ease-in-out infinite}
@keyframes moonglow{0%,100%{filter:drop-shadow(0 0 22px rgba(255,150,40,.45)) drop-shadow(0 0 60px rgba(255,120,20,.2))} 50%{filter:drop-shadow(0 0 32px rgba(255,160,50,.65)) drop-shadow(0 0 90px rgba(255,120,20,.3))}}
.np{font-family:var(--f-game); font-weight:400; color:var(--np); letter-spacing:.012em;
  text-shadow:1.5px 1.5px 0 rgba(0,0,0,.92), 0 0 3px rgba(0,0,0,.7), 0 3px 10px rgba(0,0,0,.55)}
.title{margin:0; font-size:clamp(28px,4.4vw,40px); line-height:1.1}

/* камень */
.center{display:grid; justify-items:center; align-content:center; gap:20px; padding-block:clamp(18px,4vh,44px)}
.item{position:relative; width:var(--icon); aspect-ratio:1}
.halo{position:absolute; inset:-62%; border-radius:50%; background:radial-gradient(circle, rgba(111,220,255,.30) 0%, rgba(43,182,255,.12) 34%, rgba(43,182,255,0) 64%); animation:breathe 3.4s ease-in-out infinite; pointer-events:none; transition:filter .2s}
.stone{position:relative; display:block; width:100%; height:100%; padding:0; border:0; background:none; cursor:pointer; border-radius:10px; animation:float 6s ease-in-out infinite; -webkit-tap-highlight-color:transparent}
.stone svg{position:relative; width:100%; height:100%; display:block; transition:transform .18s ease, filter .18s; filter:drop-shadow(0 18px 24px rgba(0,0,0,.6))}
.stone .hl{position:absolute; inset:6.5%; border-radius:4px; pointer-events:none; opacity:0; transition:opacity .12s; box-shadow:inset 0 0 22px 5px rgba(255,236,170,.55), inset 0 0 0 2px rgba(255,236,170,.75)}
.stone .cdw{position:absolute; inset:6.5%; border-radius:4px; pointer-events:none; background:conic-gradient(rgba(0,0,0,.72) calc(var(--p,0) * 1%), rgba(0,0,0,0) 0)}
/* «нажми меня» — золотое свечение по рамке, как у способности, которую пора применить */
.proc{position:absolute; inset:-6px; border-radius:13px; padding:3px; pointer-events:none;
  background:conic-gradient(from var(--a), rgba(255,214,90,0) 0deg, rgba(255,232,140,1) 38deg, rgba(255,214,90,0) 86deg, rgba(255,214,90,0) 180deg, rgba(255,232,140,1) 218deg, rgba(255,214,90,0) 266deg);
  -webkit-mask:linear-gradient(#000 0 0) content-box, linear-gradient(#000 0 0); -webkit-mask-composite:xor; mask-composite:exclude;
  filter:drop-shadow(0 0 6px rgba(255,200,80,.95)); animation:spin 2.6s linear infinite}
.proc::after{content:""; position:absolute; inset:-3px; border-radius:15px; box-shadow:0 0 22px 2px rgba(255,190,70,.35); animation:procpulse 1.3s ease-in-out infinite}
@keyframes spin{to{--a:360deg}}
@keyframes procpulse{0%,100%{opacity:.4} 50%{opacity:1}}
.glow{mix-blend-mode:screen; animation:pulse 2.8s ease-in-out infinite}
/* наведение: камень активен, как кнопка на панели */
.item.tip .stone svg{transform:scale(1.045); filter:drop-shadow(0 22px 28px rgba(0,0,0,.65)) brightness(1.14)}
.item.tip .hl{opacity:1}
.item.tip .halo{filter:brightness(1.6)}
.item.tip .proc{animation-duration:1.4s}
.stone:active svg{transform:scale(.965)!important; filter:drop-shadow(0 10px 16px rgba(0,0,0,.6)) brightness(.86)!important}
.casting .halo{animation:none; transform:scale(1.28); opacity:1; background:radial-gradient(circle, rgba(170,245,255,.6) 0%, rgba(43,182,255,.26) 34%, rgba(43,182,255,0) 64%); transition:transform 1.6s ease-in, opacity 1.6s}
.casting .glow{animation:none; opacity:1}
.casting .stone svg{filter:drop-shadow(0 18px 24px rgba(0,0,0,.6)) brightness(1.18) saturate(1.15)}
.casting .hl{opacity:1}
.casting .proc{opacity:0; transition:opacity .2s}
@keyframes breathe{0%,100%{transform:scale(.94); opacity:.75} 50%{transform:scale(1.06); opacity:1}}
@keyframes float{0%,100%{transform:translateY(0)} 50%{transform:translateY(-9px)}}
@keyframes pulse{0%,100%{opacity:.25} 50%{opacity:.9}}

/* подсказка предмета, появляется при наведении */
.tt{position:absolute; left:calc(100% + 22px); bottom:-2px; width:360px; z-index:6; text-align:left; background:#06091c; border:2px solid #bfc0c8; border-radius:7px; padding:11px 14px 13px; box-shadow:inset 0 0 0 1px #151827, 0 0 0 1px #000, 0 18px 40px -16px #000; font:15px/1.45 var(--f-tip); color:#fff; opacity:0; visibility:hidden; transform:translateY(4px); transition:opacity .12s, visibility .12s, transform .12s; pointer-events:none}
.item.tip .tt{opacity:1; visibility:visible; transform:none}
.tt p{margin:0}
.tt .t1{font-size:19px; line-height:1.3; margin-bottom:2px}
.tt .il{color:#ffd100}
.tt .use{color:#93ec84}
@media (max-width:860px){.tt{left:50%; bottom:auto; top:calc(100% + 62px); width:min(360px,calc(100vw - 32px)); transform:translate(-50%,4px)} .item.tip .tt{transform:translate(-50%,0)}}

/* каст */
.castslot{height:28px; width:min(330px,100%)}
.bar{position:relative; height:26px; border-radius:6px; background:rgba(0,0,0,.65); border:1px solid rgba(255,255,255,.25); overflow:hidden; box-shadow:0 0 0 1px #000}
.fill{position:absolute; inset:0 auto 0 0; width:0; background:linear-gradient(180deg,#ffe08a,#f2a322 55%,#c47408)}
.fill::after{content:""; position:absolute; right:-7px; top:-8px; bottom:-8px; width:16px; background:radial-gradient(closest-side,rgba(255,255,235,.95),rgba(255,210,120,0))}
.bar > span{position:absolute; inset:0; display:flex; justify-content:space-between; align-items:center; padding:0 10px; font:13.5px/1 var(--f-game); color:#fff; text-shadow:0 1px 2px #000}

/* отсчёт */
.count{display:grid; justify-items:center; gap:10px}
.cd{display:flex; gap:clamp(12px,3vw,28px); justify-content:center}
.cd div{display:grid; justify-items:center; min-width:clamp(54px,14vw,84px)}
.cd b{font:600 clamp(32px,7.5vw,58px)/1 var(--f-disp); letter-spacing:-.03em; font-variant-numeric:tabular-nums}
.cd small{font:11px/1 var(--f-mono); letter-spacing:.14em; text-transform:uppercase; color:var(--muted); margin-top:8px}
.when{margin:0; font:16px/1.3 var(--f-game); color:var(--muted)}
.when b{color:var(--ember); font-weight:400}

.linkbtn{font:400 18px/1.3 var(--f-game); color:#8fe0ff; text-decoration:none; border-bottom:1px solid rgba(143,224,255,.35); padding:0 0 2px}
.linkbtn:hover{color:#fff; border-color:#fff}

/* анкета */
.modal{position:fixed; inset:0; z-index:20; display:grid; place-items:center; padding:calc(16px + env(safe-area-inset-top,0px)) 16px calc(16px + env(safe-area-inset-bottom,0px)); background:rgba(3,5,9,.72); backdrop-filter:blur(8px); -webkit-backdrop-filter:blur(8px)}
.sheet{position:relative; width:min(580px,100%); max-height:100%; overflow:auto; text-align:left; background:linear-gradient(180deg,#131a25,#0d121a); border:1px solid var(--line2); border-radius:18px; padding:26px 24px 22px; box-shadow:0 40px 90px -30px #000, 0 0 60px -20px rgba(114,230,255,.35)}
.sheet.shake{animation:shake .45s}
@keyframes shake{0%,100%{transform:translateX(0)} 20%{transform:translateX(-10px)} 40%{transform:translateX(9px)} 60%{transform:translateX(-6px)} 80%{transform:translateX(4px)}}
.x{position:absolute; right:14px; top:14px; width:36px; height:36px; border-radius:50%; border:1px solid var(--line2); background:var(--s2); cursor:pointer; font-size:16px; line-height:1}
.x:hover{background:var(--s3)}
.sheet h2{margin:0 40px 18px 0; font:400 clamp(24px,4.2vw,30px)/1.15 var(--f-game); letter-spacing:.005em}
.lbl{display:block; font:600 11px/1 var(--f-mono); letter-spacing:.12em; text-transform:uppercase; color:var(--muted); margin:0 0 8px}
.grp{margin-bottom:18px}
.names{display:grid; grid-template-columns:1fr 1fr; gap:10px}
@media (max-width:420px){.names{grid-template-columns:1fr}}
.fac{display:grid; grid-template-columns:1fr 1fr; gap:8px}
.fbtn{padding:13px 12px; border-radius:12px; border:1px solid var(--line2); background:var(--s1); cursor:pointer; display:grid; gap:3px; text-align:center}
.fbtn b{font:400 17px/1.1 var(--f-game)}
.fbtn small{font-size:12px; color:var(--muted)}
.fbtn.horde{border-color:var(--horde); background:linear-gradient(180deg,rgba(224,64,47,.22),rgba(224,64,47,.06)); box-shadow:inset 0 0 0 1px rgba(224,64,47,.35)}
.fbtn.horde b{color:#ff8a78}
.fbtn.ally b{color:#8fb2ff}
.fbtn.ally:hover{border-color:var(--ally)}
.fbtn.ally.banned{cursor:not-allowed; opacity:.55; border-style:dashed}
.fbtn.ally.banned b{text-decoration:line-through; color:var(--muted)}
.inp{width:100%; font:600 17px/1.2 var(--f-body); color:var(--text); background:var(--bg); border:1px solid var(--line2); border-radius:12px; padding:13px 14px; min-width:0}
.inp:focus{outline:none; border-color:var(--rune); box-shadow:0 0 0 3px rgba(114,230,255,.15)}
.err{color:var(--bad); font-size:13px; margin-top:6px}
.tiles{display:grid; gap:8px}
.races{grid-template-columns:repeat(5,minmax(0,1fr))}
.classes{grid-template-columns:repeat(auto-fill,minmax(112px,1fr))}
@media (max-width:560px){.races{grid-template-columns:repeat(2,minmax(0,1fr))} .races .tile:last-child{grid-column:span 2}}
.tile{position:relative; padding:12px 10px; border-radius:12px; border:1px solid var(--line2); background:var(--s1); cursor:pointer; display:grid; gap:2px; text-align:left; min-width:0}
.tile b{font:400 16px/1.15 var(--f-game)}
.tile:hover{border-color:rgba(114,230,255,.45)}
.tile[aria-pressed="true"]{border-color:var(--rune); background:linear-gradient(180deg,rgba(114,230,255,.16),rgba(114,230,255,.04)); box-shadow:inset 0 0 0 1px rgba(114,230,255,.4)}
.tile .new{position:absolute; top:-7px; right:8px; font:600 9px/1 var(--f-mono); letter-spacing:.08em; text-transform:uppercase; color:#1a1004; background:var(--ember); padding:3px 5px; border-radius:4px}
.c-warrior{color:var(--warrior)} .c-rogue{color:var(--rogue)} .c-priest{color:var(--priest)} .c-mage{color:var(--mage)} .c-warlock{color:var(--warlock)} .c-hunter{color:var(--hunter)} .c-druid{color:var(--druid)} .c-shaman{color:var(--shaman)} .c-paladin{color:var(--paladin)}
.go{width:100%; margin-top:6px; padding:16px; border-radius:999px; border:0; cursor:pointer; font:400 18px/1 var(--f-game); color:#1a1004; background:linear-gradient(180deg,#ffd173,#ff9f2e); box-shadow:0 12px 30px -10px rgba(255,160,50,.7)}
.go{display:inline-flex; align-items:center; justify-content:center; text-decoration:none}
.go[disabled]{opacity:.7; cursor:progress}
.go:hover{background:linear-gradient(180deg,#ffdc8e,#ffab45)}
.ghost{padding:12px 16px; border-radius:999px; border:1px solid var(--line2); background:var(--s2); cursor:pointer; font:600 14px/1 var(--f-body)}
.ghost:hover{background:var(--s3)}
.quest .k{font:600 11px/1 var(--f-mono); letter-spacing:.14em; text-transform:uppercase; color:var(--ember); margin:0 0 10px}
.hero{display:grid; justify-items:center; gap:2px; margin:0 0 18px; padding:22px 12px 18px; border-radius:12px; background:radial-gradient(ellipse at 50% 0%, rgba(128,128,248,.14), rgba(0,0,0,0) 70%), #080b10; border:1px solid var(--line)}
.hero .np{font-size:clamp(24px,5vw,30px); line-height:1.15}
.hero .np.g{font-size:clamp(20px,4vw,24px)}
.hero .rc{font:15px/1.2 var(--f-game); color:var(--muted); margin-top:10px}
.qnote{margin:0 0 16px; font-size:15px; line-height:1.5; color:#d9d4ca; text-align:center}
.qnote b{color:var(--ember); font-weight:600}
.form-err{margin:12px 0 0; padding:10px 12px; border-radius:10px; background:rgba(255,90,90,.1); border:1px solid rgba(255,90,90,.35); color:#ffb3b3; font-size:14px}
.hp{position:absolute; left:-9999px; width:1px; height:1px; overflow:hidden}
.row{display:flex; flex-wrap:wrap; gap:10px; align-items:center; margin-top:12px}
.row .go{width:auto; margin:0; padding:14px 22px; font-size:16px}

/* тост */
.toast{position:fixed; left:50%; top:calc(16px + env(safe-area-inset-top,0px)); transform:translate(-50%,-140%); z-index:40; width:min(380px,calc(100% - 32px)); display:grid; grid-template-columns:34px 1fr; gap:12px; align-items:center; padding:12px 16px; border-radius:14px; background:rgba(20,12,14,.95); border:1px solid rgba(255,90,90,.45); box-shadow:0 20px 50px -20px #000; text-align:left; opacity:0; visibility:hidden; transition:transform .35s cubic-bezier(.2,.9,.3,1.2), opacity .2s, visibility 0s linear .35s}
.toast.on{transform:translate(-50%,0); opacity:1; visibility:visible; transition:transform .35s cubic-bezier(.2,.9,.3,1.2), opacity .2s, visibility 0s}
.toast .ti{width:34px; height:34px; border-radius:50%; display:grid; place-items:center; background:rgba(255,90,90,.16); color:var(--bad); font:800 18px/1 var(--f-disp)}
.toast b{display:block; font-size:12px; letter-spacing:.08em; text-transform:uppercase; color:var(--bad)}
.toast span{display:block; font-size:14.5px; line-height:1.35}

.flash{position:fixed; inset:0; z-index:15; pointer-events:none; background:radial-gradient(circle at 50% 48%, rgba(190,248,255,.9), rgba(114,230,255,.25) 40%, rgba(114,230,255,0) 70%); opacity:0}
.flash.on{animation:flash .7s ease-out}
@keyframes flash{0%{opacity:0} 25%{opacity:1} 100%{opacity:0}}

@media (prefers-reduced-motion: reduce){
  .halo,.stone,.glow,.moon,.proc,.proc::after{animation:none}
  .stone svg,.toast,.stone .hl,.tt{transition:none}
  .sheet.shake,.flash.on{animation:none}
  .glow{opacity:.7}
}
</style>
</head>
<body>
<canvas id="sky" aria-hidden="true"></canvas>

<div class="page" id="home">
  <header class="logo">
    <h1><img class="moon" src="img/moon.webp" alt="Reported" width="406" height="440"></h1>
    <p class="np title">&lt;Reported&gt;</p>
  </header>

  <main class="center">
    <div class="item" id="item">
      <div class="halo" aria-hidden="true"></div>
      <button class="stone" id="stone" type="button" aria-label="Камень возвращения — нажми, чтобы использовать" aria-describedby="tt">
        <span class="proc" aria-hidden="true"></span>
        <svg viewBox="0 0 64 64" aria-hidden="true">
          <defs>
            <linearGradient id="gFrame" x1="0" y1="0" x2="1" y2="1"><stop offset="0" stop-color="#e6d7a8"/><stop offset=".45" stop-color="#8e7d56"/><stop offset="1" stop-color="#3a3122"/></linearGradient>
            <linearGradient id="gGloss" x1="0" y1="0" x2="0" y2="1"><stop offset="0" stop-color="#fff" stop-opacity=".12"/><stop offset=".4" stop-color="#fff" stop-opacity="0"/></linearGradient>
            <radialGradient id="gSwirl"><stop offset="0" stop-color="#9eeaff" stop-opacity=".55"/><stop offset=".55" stop-color="#4cc8ff" stop-opacity=".2"/><stop offset="1" stop-color="#4cc8ff" stop-opacity="0"/></radialGradient>
            <clipPath id="cIcon"><rect x="4" y="4" width="56" height="56" rx="2.5"/></clipPath>
          </defs>
          <rect x=".5" y=".5" width="63" height="63" rx="5" fill="#050505"/>
          <rect x="2.2" y="2.2" width="59.6" height="59.6" rx="4" fill="none" stroke="url(#gFrame)" stroke-width="2.4"/>
          <g clip-path="url(#cIcon)">
            <image href="img/hearthstone.webp" x="4" y="4" width="56" height="56" preserveAspectRatio="none"/>
            <ellipse class="glow" cx="29.6" cy="22.8" rx="13" ry="9.5" transform="rotate(-24 29.6 22.8)" fill="url(#gSwirl)"/>
            <rect x="4" y="4" width="56" height="26" fill="url(#gGloss)"/>
          </g>
        </svg>
        <span class="cdw" id="cdw" aria-hidden="true"></span>
        <span class="hl" aria-hidden="true"></span>
      </button>
      <div class="tt" id="tt" role="tooltip">
        <p class="t1">Камень возвращения</p>
        <p class="il">Уровень предмета 1</p>
        <p>Становится персональным при получении</p>
        <p>Уникальный</p>
        <p class="use">Использование: Возвращает вас в Азерот, к гильдии &lt;Reported&gt;. Чтобы сменить место возвращения, поговорите с трактирщиком в другом месте.</p>
        <p id="cdl" hidden></p>
      </div>
    </div>
    <div class="castslot"><div class="bar" id="cast" hidden><div class="fill" id="fill"></div><span><span>Камень возвращения</span><span id="castT"></span></span></div></div>
  </main>

  <footer class="count">
    <div class="cd" id="cd" aria-live="off"></div>
    <p class="when">WoW Forever · <b>5 ноября, 02:00 МСК</b></p>
  </footer>
</div>

<div class="flash" id="flash" aria-hidden="true"></div>

<div class="modal" id="modal" hidden role="dialog" aria-modal="true" aria-labelledby="mTitle">
  <div class="sheet" id="sheet">
    <button class="x" type="button" id="close" aria-label="Закрыть">✕</button>

    <form id="form" novalidate>
      <h2 id="mTitle">Возвращение в Азерот</h2>

      <div class="grp">
        <span class="lbl">Сторона</span>
        <div class="fac">
          <button type="button" class="fbtn horde" aria-pressed="true"><b>За Орду!</b><small>единственно верный выбор</small></button>
          <button type="button" class="fbtn ally" id="ally" aria-pressed="false"><b>Альянс</b><small>серьёзно?</small></button>
        </div>
      </div>

      <div class="grp">
        <div class="names">
          <label for="first"><span class="lbl">Имя</span><input class="inp" id="first" type="text" maxlength="12" autocomplete="off" spellcheck="false" placeholder="Имя"></label>
          <label for="last"><span class="lbl">Фамилия</span><input class="inp" id="last" type="text" maxlength="16" autocomplete="off" spellcheck="false" placeholder="Фамилия"></label>
        </div>
        <div class="err" id="errNick" hidden>Имя — от 2 до 12 букв, фамилия — от 2 до 16.</div>
      </div>

      <div class="grp">
        <span class="lbl">Раса</span>
        <div class="tiles races" id="races"></div>
        <div class="err" id="errRace" hidden>Выбери расу.</div>
      </div>

      <div class="grp">
        <span class="lbl">Класс</span>
        <div class="tiles classes" id="classes"></div>
        <div class="err" id="errClass" hidden>Выбери класс.</div>
      </div>

      <label class="hp" aria-hidden="true">Сайт <input id="website" name="website" type="text" tabindex="-1" autocomplete="off"></label>
      <button class="go" type="submit" id="submitBtn">Использовать камень</button>
      <p class="form-err" id="formErr" role="alert" hidden></p>
    </form>

    <div class="quest" id="quest" hidden>
      <p class="k">Задание выполнено</p>
      <h2>Ты в ростере</h2>
      <div class="hero"><span class="np" id="qNick"></span><span class="np g">&lt;Reported&gt;</span><span class="rc" id="qRc"></span></div>
      <p class="qnote" id="qNote"></p>
      <div class="row" style="justify-content:center">
        <a class="go" href="roster.html" id="toRoster">Открыть ростер гильдии</a>
        <button class="ghost" type="button" id="edit">Изменить</button>
      </div>
    </div>
  </div>
</div>

<div class="toast" id="toast" role="status" aria-live="polite">
  <div class="ti" aria-hidden="true">!</div>
  <div><b>Жалоба принята</b><span id="toastTxt">Попытка играть за Альянс.</span></div>
</div>

<script>
(function(){
const $ = id => document.getElementById(id);
const esc = s => String(s).replace(/[&<>"']/g, c => ({'&':'&amp;','<':'&lt;','>':'&gt;','"':'&quot;',"'":'&#39;'}[c]));
const reduced = window.matchMedia && matchMedia('(prefers-reduced-motion: reduce)').matches;
const RELEASE = Date.UTC(2026, 10, 4, 23, 0, 0); // 5 ноября, 02:00 МСК

// ---------- отсчёт ----------
function tick(){
  const ms = Math.max(0, RELEASE - Date.now());
  const d = Math.floor(ms / 864e5), h = Math.floor(ms / 36e5) % 24, m = Math.floor(ms / 6e4) % 60, s = Math.floor(ms / 1e3) % 60;
  const p = n => String(n).padStart(2, '0');
  $('cd').innerHTML = ms === 0
    ? '<div><b>Мы дома</b><small>WoW Forever открыт</small></div>'
    : `<div><b>${d}</b><small>дней</small></div><div><b>${p(h)}</b><small>часов</small></div><div><b>${p(m)}</b><small>минут</small></div><div><b>${p(s)}</b><small>секунд</small></div>`;
}
tick(); setInterval(tick, 1000);

// ---------- sky ----------
(function(){
  const cv = $('sky'), cx = cv.getContext('2d');
  let W, H, stars = [], motes = [], casting = false;
  window.__cast = v => { casting = v; };
  window.__clearMotes = () => { motes = []; };
  function size(){
    const dpr = Math.min(2, window.devicePixelRatio || 1);
    W = cv.clientWidth; H = cv.clientHeight;
    cv.width = W * dpr; cv.height = H * dpr; cx.setTransform(dpr, 0, 0, dpr, 0, 0);
    stars = Array.from({length: Math.round(W * H / 5200)}, () => ({x: Math.random() * W, y: Math.random() * H, r: Math.random() * 1.2 + .2, a: Math.random() * .6 + .2, t: Math.random() * 6.28}));
    if (reduced) drawStars(false);
  }
  function drawStars(tw){ for (const s of stars){ if (tw) s.t += .012; cx.globalAlpha = s.a * (tw ? .65 + .35 * Math.sin(s.t) : 1); cx.fillStyle = '#cfe6ff'; cx.beginPath(); cx.arc(s.x, s.y, s.r, 0, 6.283); cx.fill(); } }
  function spawn(){
    if ($('home').hidden) return;
    const r = $('item').getBoundingClientRect();
    const c = {x: r.left + r.width / 2, y: r.top + r.height / 2, w: r.width};
    const ang = Math.random() * 6.283, rad = c.w * (.35 + Math.random() * .4);
    motes.push({x: c.x + Math.cos(ang) * rad, y: c.y + Math.sin(ang) * rad * .85, vy: -(.25 + Math.random() * .6) * (casting ? 2.2 : 1), vx: (Math.random() - .5) * .3, life: 0, max: 140 + Math.random() * 120, r: Math.random() * 1.8 + .6, gold: Math.random() < .16});
  }
  function frame(){
    cx.clearRect(0, 0, W, H); drawStars(true);
    const n = casting ? 5 : (Math.random() < .5 ? 1 : 0);
    for (let i = 0; i < n; i++) spawn();
    motes = motes.filter(m => m.life < m.max);
    for (const m of motes){
      m.life++; m.x += m.vx + Math.sin(m.life / 18) * .15; m.y += m.vy;
      const k = m.life / m.max, a = k < .15 ? k / .15 : 1 - (k - .15) / .85;
      cx.globalAlpha = Math.max(0, a) * .9;
      const g = cx.createRadialGradient(m.x, m.y, 0, m.x, m.y, m.r * 4);
      g.addColorStop(0, m.gold ? 'rgba(255,214,130,1)' : 'rgba(170,245,255,1)'); g.addColorStop(1, 'rgba(114,230,255,0)');
      cx.fillStyle = g; cx.beginPath(); cx.arc(m.x, m.y, m.r * 4, 0, 6.283); cx.fill();
    }
    cx.globalAlpha = 1;
    if (!document.hidden) requestAnimationFrame(frame); else document.addEventListener('visibilitychange', () => requestAnimationFrame(frame), {once: true});
  }
  size(); window.addEventListener('resize', size);
  if (!reduced) requestAnimationFrame(frame);
})();


const item = $('item');

// ---------- наведение: подсказка и активный камень ----------
$('stone').addEventListener('pointerenter', e => { if (e.pointerType === 'mouse') item.classList.add('tip'); });
$('stone').addEventListener('pointerleave', e => { if (e.pointerType === 'mouse' && !casting) item.classList.remove('tip'); });
$('stone').addEventListener('focus', () => { let kb = true; try { kb = $('stone').matches(':focus-visible'); } catch (e) {} if (kb) item.classList.add('tip'); });
$('stone').addEventListener('blur', () => { if (!casting) item.classList.remove('tip'); });

// ---------- races & classes (только Орда) ----------
const RACES = [
  {k:'orc', n:'Орк', cls:['warrior','hunter','rogue','shaman','mage','warlock'], nw:['mage']},
  {k:'undead', n:'Нежить', cls:['warrior','paladin','rogue','priest','mage','warlock'], nw:['paladin']},
  {k:'tauren', n:'Таурен', cls:['warrior','hunter','shaman','druid'], nw:[]},
  {k:'troll', n:'Тролль', cls:['warrior','hunter','rogue','priest','shaman','mage','warlock'], nw:['warlock']},
  {k:'sky', n:'Скайборн', cls:['warrior','hunter','rogue','shaman','druid'], nw:[], isNew:true}
];
const CLASSES = {warrior:'Воин', hunter:'Охотник', rogue:'Разбойник', shaman:'Шаман', mage:'Маг', warlock:'Чернокнижник', paladin:'Паладин', priest:'Жрец', druid:'Друид'};
let race = null, klass = null;
function renderRaces(){
  $('races').innerHTML = RACES.map(r => `<button type="button" class="tile" data-race="${r.k}" aria-pressed="${race === r.k}">${r.isNew ? '<span class="new">new</span>' : ''}<b>${esc(r.n)}</b></button>`).join('');
}
function renderClasses(){
  const r = RACES.find(x => x.k === race);
  if (!r){ $('classes').innerHTML = '<p style="margin:0; grid-column:1/-1; color:var(--muted); font-size:14px">Сначала раса.</p>'; return; }
  $('classes').innerHTML = r.cls.map(c => `<button type="button" class="tile" data-class="${c}" aria-pressed="${klass === c}">${r.nw.includes(c) ? '<span class="new">new</span>' : ''}<b class="c-${c}">${CLASSES[c]}</b></button>`).join('');
}
renderRaces(); renderClasses();
$('races').addEventListener('click', e => {
  const b = e.target.closest('[data-race]'); if (!b) return;
  race = b.dataset.race; const r = RACES.find(x => x.k === race);
  if (klass && !r.cls.includes(klass)) klass = null;
  $('errRace').hidden = true; renderRaces(); renderClasses();
});
$('classes').addEventListener('click', e => {
  const b = e.target.closest('[data-class]'); if (!b) return;
  klass = b.dataset.class; $('errClass').hidden = true; renderClasses();
});


// ---------- Альянс ----------
let toastTimer, allyTries = 0;
const ALLY_MSG = ['Попытка играть за Альянс. Выбор недоступен.', 'Повторная попытка уйти в Альянс. Сообщено офицерам.', 'Хватит. Ты в Орде.'];
function toast(txt){ $('toastTxt').textContent = txt; $('toast').classList.add('on'); clearTimeout(toastTimer); toastTimer = setTimeout(() => $('toast').classList.remove('on'), 4200); }
$('ally').addEventListener('click', () => {
  toast(ALLY_MSG[Math.min(allyTries, ALLY_MSG.length - 1)]); allyTries++;
  $('ally').classList.add('banned'); $('ally').querySelector('small').textContent = 'заблокировано репортом';
  const s = $('sheet'); s.classList.remove('shake'); void s.offsetWidth; s.classList.add('shake');
});


// ---------- кто уже в гильдии ----------
function myToken(){ try { const m = JSON.parse(localStorage.getItem('reported_me') || 'null'); return m && /^[a-f0-9]{32}$/.test(m.token || '') ? m.token : ''; } catch (e) { return ''; } }
let teleporting = false;
function teleport(){ teleporting = true; $('flash').classList.remove('on'); void $('flash').offsetWidth; $('flash').classList.add('on'); setTimeout(() => { location.href = 'roster.html#chat'; }, 350); }
const wantEdit = location.hash === '#edit';
window.addEventListener('pageshow', e => { if (e.persisted && teleporting){ teleporting = false; sending = false; const b = $('submitBtn'); b.disabled = false; b.textContent = 'Использовать камень'; $('modal').hidden = true; } });

// ---------- каст, откат, анкета ----------
let casting = false, lastFocus = null;
function openModal(){ lastFocus = document.activeElement; $('modal').hidden = false; setTimeout(() => ($('quest').hidden ? $('first') : $('toRoster')).focus(), 30); }
function closeModal(){ $('modal').hidden = true; try { (lastFocus || $('stone')).focus(); } catch (e) {} }
function cooldown(T){
  const el = $('cdw'), t0 = performance.now(), cl = $('cdl');
  cl.hidden = false;
  (function st(now){
    const k = Math.min(1, (now - t0) / T);
    el.style.setProperty('--p', ((1 - k) * 100).toFixed(2));
    cl.textContent = 'Время восстановления: ' + Math.max(1, Math.ceil((T - k * T) / 1000)) + ' сек.';
    if (k < 1) requestAnimationFrame(st); else { el.style.removeProperty('--p'); cl.hidden = true; }
  })(t0);
}
$('stone').addEventListener('click', () => {
  if (casting) return;
  if (reduced){ if (myToken() && !wantEdit) teleport(); else openModal(); return; }
  casting = true; window.__cast && window.__cast(true);
  item.classList.add('casting', 'tip'); $('cast').hidden = false;
  const T = 1800, t0 = performance.now();
  (function step(now){
    const k = Math.min(1, (now - t0) / T);
    $('fill').style.width = (k * 100) + '%';
    $('castT').textContent = ((T - k * T) / 1000).toFixed(1);
    if (k < 1) requestAnimationFrame(step);
    else {
      $('flash').classList.remove('on'); void $('flash').offsetWidth; $('flash').classList.add('on');
      setTimeout(() => {
        casting = false; window.__cast && window.__cast(false);
        item.classList.remove('casting', 'tip'); $('cast').hidden = true; $('fill').style.width = '0';
        if (myToken() && !wantEdit){ teleport(); return; }   // уже в гильдии — камень переносит домой, в чат
        cooldown(8000); openModal();
      }, 180);
    }
  })(t0);
});
$('close').addEventListener('click', closeModal);
$('modal').addEventListener('click', e => { if (e.target === $('modal')) closeModal(); });
document.addEventListener('keydown', e => { if (e.key === 'Escape' && !$('modal').hidden) closeModal(); });

// ---------- отправка анкеты: запись сразу уходит на сервер ----------
const cap = w => w ? w.charAt(0).toUpperCase() + w.slice(1).toLowerCase() : '';
function plural(n, a, b, c){ const m10 = n % 10, m100 = n % 100; return m10 === 1 && m100 !== 11 ? a : (m10 >= 2 && m10 <= 4 && (m100 < 10 || m100 >= 20)) ? b : c; }
let sending = false;
$('form').addEventListener('submit', async e => {
  e.preventDefault();
  if (sending) return;
  const f = $('first').value.trim(), l = $('last').value.trim();
  const okNick = /^[A-Za-zА-Яа-яЁё]{2,12}$/.test(f) && (!l || /^[A-Za-zА-Яа-яЁё]{2,16}$/.test(l));
  $('errNick').hidden = okNick; $('errRace').hidden = !!race; $('errClass').hidden = !!klass; $('formErr').hidden = true;
  if (!okNick){ $('first').focus(); return; }
  if (!race || !klass) return;
  sending = true;
  const btn = $('submitBtn'); btn.disabled = true; btn.textContent = 'Камень работает…';
  const fail = msg => { $('formErr').textContent = msg; $('formErr').hidden = false; };
  try {
    let res;
    try {
      res = await fetch('api.php?action=register', {method: 'POST', headers: {'Content-Type': 'application/json'},
        body: JSON.stringify({first: cap(f), last: cap(l), race, cls: klass, website: $('website').value, token: myToken()})});
    } catch (netErr) { fail('Нет связи с сервером. Проверь интернет и попробуй ещё раз.'); return; }
    let data = null;
    try { data = await res.json(); } catch (x) {}
    if (!res.ok || !data || !data.ok){ fail((data && data.message) || 'Сервер не ответил как надо. Попробуй ещё раз через минуту.'); return; }
    const en = data.entry, r = RACES.find(x => x.k === en.race);
    const nick = en.first + (en.last ? ' ' + en.last : '');
    $('qNick').textContent = nick;
    $('qRc').innerHTML = `${esc(r ? r.n : '')} · <span class="c-${esc(en.cls)}">${esc(CLASSES[en.cls] || '')}</span>`;
    $('qNote').innerHTML = data.updated
      ? `Запись обновлена. Ты <b>№${data.place}</b> в ростере гильдии.`
      : `Ты <b>№${data.place}</b> в ростере гильдии. Сбор — 5 ноября в 02:00 по Москве.`;
    try { localStorage.setItem('reported_me', JSON.stringify({first: en.first, last: en.last, id: en.id, token: data.token || ''})); } catch (x) {}
    // сразу в гильдейский чат
    btn.textContent = 'Переносимся в гильдию…'; teleport(); return;
  } finally {
    if (!teleporting){ sending = false; btn.disabled = false; btn.textContent = 'Использовать камень'; }
  }
});
$('edit').addEventListener('click', () => { $('quest').hidden = true; $('form').hidden = false; $('first').focus(); });

})();
</script>
</body>
</html>
