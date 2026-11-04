// Общие данные и иконки для ростера и настроек гильдии.
(function(){
const G = window.G = {};

G.RACES = {orc:'Орк', undead:'Нежить', tauren:'Таурен', troll:'Тролль', sky:'Скайборн'};
G.CLASSES = {warrior:'Воин', hunter:'Охотник', rogue:'Разбойник', shaman:'Шаман', mage:'Маг', warlock:'Чернокнижник', paladin:'Паладин', priest:'Жрец', druid:'Друид'};
G.CLS_ORDER = ['warrior','paladin','hunter','rogue','priest','shaman','mage','warlock','druid'];
G.CLS_PL = {warrior:['воин','воина','воинов'], hunter:['охотник','охотника','охотников'], rogue:['разбойник','разбойника','разбойников'], shaman:['шаман','шамана','шаманов'], mage:['маг','мага','магов'], warlock:['чернокнижник','чернокнижника','чернокнижников'], paladin:['паладин','паладина','паладинов'], priest:['жрец','жреца','жрецов'], druid:['друид','друида','друидов']};
G.RANKS = ['Глава гильдии', 'Офицер', 'Ветеран', 'Участник', 'Новобранец'];
G.RGB = {warrior:'198,155,109', rogue:'255,244,104', priest:'244,244,244', mage:'63,199,235', warlock:'151,152,245', hunter:'170,211,114', druid:'255,124,10', shaman:'61,155,255', paladin:'244,140,186'};
G.RELEASE = Date.UTC(2026, 10, 4, 23, 0, 0); // 5 ноября, 02:00 МСК

G.esc = s => String(s).replace(/[&<>"']/g, c => ({'&':'&amp;','<':'&lt;','>':'&gt;','"':'&quot;',"'":'&#39;'}[c]));
G.plural = (n, f) => { const a = n % 10, b = n % 100; return a === 1 && b !== 11 ? f[0] : (a >= 2 && a <= 4 && (b < 10 || b >= 20)) ? f[1] : f[2]; };
G.fullName = e => e.first + (e.last ? ' ' + e.last : '');
G.rankName = r => G.RANKS[r] != null ? G.RANKS[r] : G.RANKS[3];
const MONTHS = ['января','февраля','марта','апреля','мая','июня','июля','августа','сентября','октября','ноября','декабря'];
G.dateLong = s => { const m = /^(\d{4})-(\d{2})-(\d{2})$/.exec(s || ''); return m ? (+m[3]) + ' ' + MONTHS[+m[2] - 1] : ''; };
G.dateShort = s => { const m = /^(\d{4})-(\d{2})-(\d{2})$/.exec(s || ''); return m ? m[3] + '.' + m[2] : ''; };
G.daysLeft = () => Math.max(0, Math.floor((G.RELEASE - Date.now()) / 864e5));

// Иконки классов — настоящие игровые (вырезаны со скриншота foreverchanges.pro).
G.classIcon = (cls, size) => {
  if (!G.CLASSES[cls]) return '<span class="ci"></span>';
  return `<span class="ci"${size ? ` data-size="${size}"` : ''} aria-hidden="true"><img src="img/cls/${cls}.webp" alt="" width="52" height="52" decoding="async"></span>`;
};

// Портреты рас Орды — настоящие игровые (со скриншота foreverchanges.pro).
G.raceIcon = race => G.RACES[race] ? `<span class="ri" aria-hidden="true"><img src="img/race/${race}.webp" alt="" width="72" height="72" decoding="async"></span>` : '';

// Эмблема гильдии — рогатый шлем, как на гербе Reported в игре.
G.emblem = '<svg class="emb" viewBox="0 0 64 64" aria-hidden="true"><defs><linearGradient id="embM" x1="0" y1="0" x2="0" y2="1"><stop offset="0" stop-color="#d9d9dc"/><stop offset=".55" stop-color="#8e8f95"/><stop offset="1" stop-color="#4b4c52"/></linearGradient></defs>'
  + '<path d="M19 31C8.5 29.5 2.6 19.6 4.6 4.2 7.6 13 12.6 17.4 22 19.4z" fill="url(#embM)" stroke="#1a1a1c" stroke-width="1.6" stroke-linejoin="round"/>'
  + '<path d="M45 31c10.5-1.5 16.4-11.4 14.4-26.8C56.4 13 51.4 17.4 42 19.4z" fill="url(#embM)" stroke="#1a1a1c" stroke-width="1.6" stroke-linejoin="round"/>'
  + '<path d="M32 13c-10.5 0-17.4 7.6-17.4 18.2V50c0 3 2 5 5 6l6.4 2.4V40h12v18.4l6.4-2.4c3-1 5-3 5-6V31.2C49.4 20.6 42.5 13 32 13z" fill="url(#embM)" stroke="#1a1a1c" stroke-width="1.8" stroke-linejoin="round"/>'
  + '<path d="M19.6 33.4h24.8v4.8H19.6z" fill="#161618"/><path d="M29.8 38h4.4v17.4h-4.4z" fill="#161618"/>'
  + '<path d="M32 16.4v14" stroke="#f2f2f4" stroke-width="1.4" opacity=".55"/><path d="M19 30c1-6.6 5.8-11.8 13-12.6" fill="none" stroke="#fff" stroke-width="1.3" opacity=".35"/></svg>';
})();
