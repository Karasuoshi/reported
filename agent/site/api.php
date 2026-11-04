<?php
// Reported — камень возвращения, ростер, гильдейский чат и настройки гильдии.
// Данные лежат в data/*.php: файлы начинаются с защиты, через браузер их не прочитать.

header('Content-Type: application/json; charset=utf-8');
header('Cache-Control: no-store');
header('X-Content-Type-Options: nosniff');
date_default_timezone_set('Europe/Moscow');

$CFG = require __DIR__ . '/config.php';
$DATA_DIR = __DIR__ . '/data';
$DB_FILE = $DATA_DIR . '/roster.php';
$LIMIT_FILE = $DATA_DIR . '/limits.php';
$CHAT_FILE = $DATA_DIR . '/chat.php';
$SET_FILE = $DATA_DIR . '/settings.php';
$SEEN_FILE = $DATA_DIR . '/seen.php';
$GUARD = "<?php http_response_code(404); exit; ?>\n";

$RACES = ['orc' => 'Орк', 'undead' => 'Нежить', 'tauren' => 'Таурен', 'troll' => 'Тролль', 'sky' => 'Скайборн'];
$RACE_CLS = [
    'orc'    => ['warrior', 'hunter', 'rogue', 'shaman', 'mage', 'warlock'],
    'undead' => ['warrior', 'paladin', 'rogue', 'priest', 'mage', 'warlock'],
    'tauren' => ['warrior', 'hunter', 'shaman', 'druid'],
    'troll'  => ['warrior', 'hunter', 'rogue', 'priest', 'shaman', 'mage', 'warlock'],
    'sky'    => ['warrior', 'hunter', 'rogue', 'shaman', 'druid'],
];
$MAX_ENTRIES = 500;
// звания как в игре: 0 — глава гильдии … 4 — новобранец
$RANKS = ['Глава гильдии', 'Офицер', 'Ветеран', 'Участник', 'Новобранец'];
$DEFAULT_RANK = 3;
$NOTE_MAX = 31;   // как заметка в игре
$MOTD_MAX = 128;  // как сообщение дня в игре
$MSG_MAX = 255;   // как строка чата в игре
$CHAT_KEEP = 500; // сколько последних сообщений хранить
$DEFAULT_MOTD = 'Старт WoW Forever — 5 ноября, 02:00 по Москве. Кто в ростере — не опаздывать.';

function out($code, $arr) {
    http_response_code($code);
    echo json_encode($arr, JSON_UNESCAPED_UNICODE);
    exit;
}

function fail($code, $error, $message) {
    out($code, ['ok' => false, 'error' => $error, 'message' => $message]);
}

function input() {
    static $cache = null;
    if ($cache !== null) return $cache;
    $raw = file_get_contents('php://input');
    $j = json_decode($raw ? $raw : '', true);
    $cache = is_array($j) ? $j : $_POST;
    return $cache;
}

function ensure_dir($dir) {
    if (!is_dir($dir)) @mkdir($dir, 0755, true);
    if (!is_dir($dir) || !is_writable($dir)) fail(500, 'storage', 'Сервер не может сохранить данные: нет доступа к папке data.');
}

// Читает и меняет файл под блокировкой. $fn получает массив и возвращает [новый_массив, результат].
function locked_update($file, $guard, $fn) {
    $fp = @fopen($file, 'c+');
    if (!$fp) fail(500, 'storage', 'Сервер не может открыть файл с данными.');
    flock($fp, LOCK_EX);
    $raw = stream_get_contents($fp);
    $data = decode_guarded($raw, $guard);
    list($next, $result) = $fn($data);
    ftruncate($fp, 0);
    rewind($fp);
    fwrite($fp, $guard . json_encode($next, JSON_UNESCAPED_UNICODE));
    fflush($fp);
    flock($fp, LOCK_UN);
    fclose($fp);
    return $result;
}

function read_guarded($file, $guard) {
    if (!is_file($file)) return [];
    $fp = @fopen($file, 'r');
    if (!$fp) return [];
    flock($fp, LOCK_SH);
    $raw = stream_get_contents($fp);
    flock($fp, LOCK_UN);
    fclose($fp);
    return decode_guarded($raw, $guard);
}

function decode_guarded($raw, $guard) {
    if (!$raw) return [];
    if (strpos($raw, $guard) === 0) $raw = substr($raw, strlen($guard));
    $d = json_decode($raw, true);
    return is_array($d) ? $d : [];
}

function clean_name($s, $max, $required) {
    $s = trim((string)$s);
    if ($s === '' && !$required) return '';
    if (!preg_match('/^[A-Za-zА-Яа-яЁё]{2,' . $max . '}$/u', $s)) return null;
    return mb_strtoupper(mb_substr($s, 0, 1, 'UTF-8'), 'UTF-8') . mb_strtolower(mb_substr($s, 1, null, 'UTF-8'), 'UTF-8');
}

function clean_text($s, $max) {
    $s = (string)$s;
    if (!preg_match('//u', $s)) return '';
    $s = preg_replace('/[\x00-\x1F\x7F]/u', ' ', $s);
    $s = trim(preg_replace('/\s+/u', ' ', $s));
    return mb_substr($s, 0, $max, 'UTF-8');
}

function new_id($bytes = 6) {
    if (function_exists('random_bytes')) return bin2hex(random_bytes($bytes));
    if (function_exists('openssl_random_pseudo_bytes')) return bin2hex(openssl_random_pseudo_bytes($bytes));
    $s = '';
    while (strlen($s) < $bytes * 2) $s .= md5(uniqid('', true) . mt_rand());
    return substr($s, 0, $bytes * 2);
}

function full_name($e) {
    return trim($e['first'] . ' ' . $e['last']);
}

function public_entry($e) {
    return [
        'id' => $e['id'], 'first' => $e['first'], 'last' => $e['last'], 'race' => $e['race'], 'cls' => $e['cls'], 'at' => $e['at'],
        'ts' => isset($e['ts']) ? (int)$e['ts'] : 0,
        'rank' => isset($e['rank']) ? (int)$e['rank'] : 3,
        'note' => isset($e['note']) ? (string)$e['note'] : '',
    ];
}

function public_msg($m) {
    return ['id' => (int)$m['id'], 'eid' => $m['eid'], 'n' => $m['n'], 'c' => $m['c'], 'ts' => (int)$m['ts'], 't' => $m['t']];
}

function valid_token($t) {
    return is_string($t) && preg_match('/^[a-f0-9]{32}$/', $t);
}

// Кто пишет: ищем члена гильдии по личному ключу.
function member_by_token($all, $tok) {
    if (!valid_token($tok)) return null;
    foreach ($all as $e) {
        if (!empty($e['tok']) && hash_equals($e['tok'], $tok)) return $e;
    }
    return null;
}

function client_ip() {
    $ip = isset($_SERVER['REMOTE_ADDR']) ? $_SERVER['REMOTE_ADDR'] : '0';
    if (($ip === '127.0.0.1' || $ip === '::1') && !empty($_SERVER['HTTP_X_REAL_IP'])) $ip = $_SERVER['HTTP_X_REAL_IP'];
    return $ip;
}

function is_admin($CFG) {
    $in = input();
    $key = isset($in['key']) ? (string)$in['key'] : '';
    return $key !== '' && hash_equals((string)$CFG['admin_password'], $key);
}

function check_admin($CFG) {
    if (!is_admin($CFG)) {
        usleep(800000);
        fail(403, 'bad_password', 'Неверный пароль.');
    }
}

function get_motd($SET_FILE, $GUARD, $DEFAULT_MOTD) {
    $s = read_guarded($SET_FILE, $GUARD);
    return isset($s['motd']) ? (string)$s['motd'] : $DEFAULT_MOTD;
}

$action = isset($_GET['action']) ? $_GET['action'] : '';
$method = isset($_SERVER['REQUEST_METHOD']) ? $_SERVER['REQUEST_METHOD'] : 'GET';

if ($action === 'list') {
    $all = read_guarded($DB_FILE, $GUARD);
    out(200, ['ok' => true, 'entries' => array_map('public_entry', array_values($all)), 'motd' => get_motd($SET_FILE, $GUARD, $DEFAULT_MOTD), 'now' => date('c')]);
}

if ($method !== 'POST') fail(405, 'method', 'Нужен POST-запрос.');
ensure_dir($DATA_DIR);

if ($action === 'register') {
    $in = input();
    if (!empty($in['website'])) fail(400, 'spam', 'Запрос отклонён.'); // ловушка для ботов
    $first = clean_name(isset($in['first']) ? $in['first'] : '', 12, true);
    $last = clean_name(isset($in['last']) ? $in['last'] : '', 16, false);
    if ($first === null || $last === null) fail(422, 'invalid_name', 'Имя — от 2 до 12 букв, фамилия — от 2 до 16. Только буквы.');
    $race = isset($in['race']) ? (string)$in['race'] : '';
    $cls = isset($in['cls']) ? (string)$in['cls'] : '';
    if (!isset($RACE_CLS[$race])) fail(422, 'invalid_race', 'Такой расы у Орды нет.');
    if (!in_array($cls, $RACE_CLS[$race], true)) fail(422, 'invalid_class', 'Эта раса не может быть этим классом.');
    $tokIn = isset($in['token']) ? (string)$in['token'] : '';

    // защита от спама: не больше 15 записей за 10 минут и 60 в сутки с одного адреса
    $who = hash('sha256', $CFG['salt'] . '|' . client_ip());
    $now = time();
    $allowed = locked_update($LIMIT_FILE, $GUARD, function ($lim) use ($who, $now) {
        foreach ($lim as $k => $times) {
            $lim[$k] = array_values(array_filter($times, function ($t) use ($now) { return $t > $now - 86400; }));
            if (!$lim[$k]) unset($lim[$k]);
        }
        $mine = isset($lim[$who]) ? $lim[$who] : [];
        $recent = count(array_filter($mine, function ($t) use ($now) { return $t > $now - 600; }));
        if ($recent >= 15 || count($mine) >= 60) return [$lim, false];
        $mine[] = $now;
        $lim[$who] = $mine;
        return [$lim, true];
    });
    if (!$allowed) fail(429, 'rate_limited', 'Слишком много записей подряд. Попробуй через 10 минут.');

    $key = mb_strtolower(trim($first . ' ' . $last), 'UTF-8');
    $result = locked_update($DB_FILE, $GUARD, function ($all) use ($first, $last, $race, $cls, $key, $now, $MAX_ENTRIES, $DEFAULT_RANK, $tokIn) {
        $all = array_values($all);
        foreach ($all as $i => $e) {
            if (mb_strtolower(full_name($e), 'UTF-8') === $key) {
                // имя уже занято: менять запись может только тот, кто её создал
                if (!empty($e['tok']) && !(valid_token($tokIn) && hash_equals($e['tok'], $tokIn))) return [$all, 'taken'];
                if (empty($e['tok'])) $all[$i]['tok'] = new_id(16);
                $all[$i]['race'] = $race;
                $all[$i]['cls'] = $cls;
                $all[$i]['updated'] = $now;
                return [$all, ['entry' => $all[$i], 'place' => $i + 1, 'count' => count($all), 'updated' => true]];
            }
        }
        if (count($all) >= $MAX_ENTRIES) return [$all, null];
        $e = ['id' => new_id(), 'first' => $first, 'last' => $last, 'race' => $race, 'cls' => $cls, 'at' => date('Y-m-d'), 'ts' => $now, 'rank' => $DEFAULT_RANK, 'note' => '', 'tok' => new_id(16)];
        $all[] = $e;
        return [$all, ['entry' => $e, 'place' => count($all), 'count' => count($all), 'updated' => false]];
    });
    if ($result === null) fail(507, 'full', 'Ростер заполнен. Напиши офицерам гильдии.');
    if ($result === 'taken') fail(409, 'name_taken', 'Персонаж с таким именем уже в ростере. Если это ты — зайди с того устройства, где записывался, или попроси у офицера личную ссылку.');
    out(200, ['ok' => true, 'entry' => public_entry($result['entry']), 'token' => $result['entry']['tok'], 'place' => $result['place'], 'count' => $result['count'], 'updated' => $result['updated']]);
}

if ($action === 'whoami') {
    $in = input();
    $me = member_by_token(read_guarded($DB_FILE, $GUARD), isset($in['token']) ? $in['token'] : '');
    if (!$me) fail(403, 'not_member', 'Ключ не подходит: такого члена гильдии нет.');
    out(200, ['ok' => true, 'entry' => public_entry($me)]);
}

// ---------- гильдейский чат ----------
if ($action === 'chat_list') {
    $in = input();
    $me = null;
    if (!is_admin($CFG)) {
        $me = member_by_token(read_guarded($DB_FILE, $GUARD), isset($in['token']) ? $in['token'] : '');
        if (!$me) fail(403, 'not_member', 'Гильдейский чат видят только члены гильдии.');
    }
    // кто сейчас «в сети»: открывал сайт за последние 45 секунд
    $mark = function ($seen) use ($me) {
        $now = time();
        if ($me) $seen[$me['id']] = $now;
        $on = [];
        foreach ($seen as $k => $t) {
            if ($t < $now - 86400 * 60) unset($seen[$k]);
            elseif ($t >= $now - 45) $on[] = $k;
        }
        return [$seen, $on];
    };
    if ($me) $online = locked_update($SEEN_FILE, $GUARD, $mark);
    else { list(, $online) = $mark(read_guarded($SEEN_FILE, $GUARD)); }
    $since = isset($in['since']) ? (int)$in['since'] : 0;
    $chat = read_guarded($CHAT_FILE, $GUARD);
    $msgs = isset($chat['msgs']) ? $chat['msgs'] : [];
    $new = array_values(array_filter($msgs, function ($m) use ($since) { return (int)$m['id'] > $since; }));
    if (count($new) > 200) $new = array_slice($new, -200);
    $ids = array_map(function ($m) { return (int)$m['id']; }, $msgs);
    out(200, ['ok' => true, 'msgs' => array_map('public_msg', $new), 'ids' => $ids, 'online' => $online, 'motd' => get_motd($SET_FILE, $GUARD, $DEFAULT_MOTD)]);
}

if ($action === 'chat_send') {
    $in = input();
    $me = member_by_token(read_guarded($DB_FILE, $GUARD), isset($in['token']) ? $in['token'] : '');
    if (!$me) fail(403, 'not_member', 'Писать в гильдейский чат могут только члены гильдии.');
    $text = clean_text(isset($in['text']) ? $in['text'] : '', $MSG_MAX);
    if ($text === '') fail(422, 'empty', 'Пустое сообщение.');
    $now = microtime(true);
    $res = locked_update($CHAT_FILE, $GUARD, function ($chat) use ($me, $text, $now, $CHAT_KEEP) {
        $msgs = isset($chat['msgs']) ? $chat['msgs'] : [];
        $next = isset($chat['next']) ? (int)$chat['next'] : 1;
        $rl = isset($chat['rl']) ? $chat['rl'] : [];
        foreach ($rl as $k => $times) {
            $rl[$k] = array_values(array_filter($times, function ($t) use ($now) { return $t > $now - 60; }));
            if (!$rl[$k]) unset($rl[$k]);
        }
        $mine = isset($rl[$me['id']]) ? $rl[$me['id']] : [];
        if ($mine && $now - end($mine) < 1.2) return [$chat, 'fast'];
        if (count($mine) >= 20) return [$chat, 'flood'];
        $mine[] = $now;
        $rl[$me['id']] = $mine;
        $m = ['id' => $next, 'eid' => $me['id'], 'n' => full_name($me), 'c' => $me['cls'], 'ts' => (int)$now, 't' => $text];
        $msgs[] = $m;
        if (count($msgs) > $CHAT_KEEP) $msgs = array_slice($msgs, -$CHAT_KEEP);
        return [['msgs' => $msgs, 'next' => $next + 1, 'rl' => $rl], $m];
    });
    if ($res === 'fast') fail(429, 'too_fast', 'Не так быстро.');
    if ($res === 'flood') fail(429, 'flood', 'Слишком много сообщений подряд. Подожди минуту.');
    out(200, ['ok' => true, 'msg' => public_msg($res)]);
}

if ($action === 'chat_delete') {
    check_admin($CFG);
    $in = input();
    $id = isset($in['id']) ? (int)$in['id'] : 0;
    $removed = locked_update($CHAT_FILE, $GUARD, function ($chat) use ($id) {
        $msgs = isset($chat['msgs']) ? $chat['msgs'] : [];
        $before = count($msgs);
        $chat['msgs'] = array_values(array_filter($msgs, function ($m) use ($id) { return (int)$m['id'] !== $id; }));
        return [$chat, $before !== count($chat['msgs'])];
    });
    if (!$removed) fail(404, 'not_found', 'Сообщение уже удалено.');
    out(200, ['ok' => true]);
}

if ($action === 'chat_clear') {
    check_admin($CFG);
    locked_update($CHAT_FILE, $GUARD, function ($chat) {
        $chat['msgs'] = [];
        return [$chat, true];
    });
    out(200, ['ok' => true]);
}

if ($action === 'motd_set') {
    check_admin($CFG);
    $in = input();
    $motd = clean_text(isset($in['motd']) ? $in['motd'] : '', $MOTD_MAX);
    locked_update($SET_FILE, $GUARD, function ($s) use ($motd) {
        $s['motd'] = $motd;
        return [$s, true];
    });
    out(200, ['ok' => true, 'motd' => $motd]);
}

// ---------- настройки гильдии ----------
if ($action === 'admin_list') {
    check_admin($CFG);
    $all = array_values(read_guarded($DB_FILE, $GUARD));
    $rows = array_map(function ($e) {
        $p = public_entry($e);
        $p['time'] = isset($e['ts']) ? date('d.m.Y H:i', $e['ts']) : '';
        $p['changed'] = isset($e['updated']) ? date('d.m.Y H:i', $e['updated']) : '';
        return $p;
    }, $all);
    out(200, ['ok' => true, 'entries' => $rows, 'motd' => get_motd($SET_FILE, $GUARD, $DEFAULT_MOTD)]);
}

// личная ссылка для входа в чат с другого устройства
if ($action === 'member_link') {
    check_admin($CFG);
    $in = input();
    $id = isset($in['id']) ? (string)$in['id'] : '';
    $tok = locked_update($DB_FILE, $GUARD, function ($all) use ($id) {
        $all = array_values($all);
        foreach ($all as $i => $e) {
            if ($e['id'] === $id) {
                if (empty($e['tok'])) $all[$i]['tok'] = new_id(16);
                return [$all, $all[$i]['tok']];
            }
        }
        return [$all, null];
    });
    if (!$tok) fail(404, 'not_found', 'Запись не найдена.');
    out(200, ['ok' => true, 'token' => $tok]);
}

if ($action === 'update') {
    check_admin($CFG);
    $in = input();
    $id = isset($in['id']) ? (string)$in['id'] : '';
    $rank = isset($in['rank']) ? (int)$in['rank'] : -1;
    if ($rank < 0 || $rank >= count($RANKS)) fail(422, 'invalid_rank', 'Такого звания нет.');
    $note = clean_text(str_replace(['<', '>'], '', isset($in['note']) ? $in['note'] : ''), $NOTE_MAX);
    $saved = locked_update($DB_FILE, $GUARD, function ($all) use ($id, $rank, $note) {
        $all = array_values($all);
        foreach ($all as $i => $e) {
            if ($e['id'] === $id) {
                $all[$i]['rank'] = $rank;
                $all[$i]['note'] = $note;
                return [$all, $all[$i]];
            }
        }
        return [$all, null];
    });
    if (!$saved) fail(404, 'not_found', 'Запись не найдена — возможно, её уже удалили.');
    out(200, ['ok' => true, 'entry' => public_entry($saved)]);
}

if ($action === 'delete') {
    check_admin($CFG);
    $in = input();
    $id = isset($in['id']) ? (string)$in['id'] : '';
    $removed = locked_update($DB_FILE, $GUARD, function ($all) use ($id) {
        $before = count($all);
        $all = array_values(array_filter($all, function ($e) use ($id) { return $e['id'] !== $id; }));
        return [$all, $before !== count($all)];
    });
    if (!$removed) fail(404, 'not_found', 'Запись уже удалена.');
    out(200, ['ok' => true]);
}

fail(400, 'unknown_action', 'Неизвестное действие.');
