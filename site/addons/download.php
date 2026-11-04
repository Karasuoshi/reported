<?php
// Скачивание аддона одним zip, архив собирается на лету.
//   addons/download.php?id=<id>  -> <folder>-<version>.zip, внутри папка <folder>/ с файлами аддона
//   addons/download.php?stats=1  -> {"ok":true,"counts":{"<id>":N}} для счётчика на addons.html
// id берётся только из addons.json (белый список). В архив попадают только *.toc, *.lua, *.xml
// из папки аддона (вложенные папки тоже, без ссылок-ярлыков). Zip собирается вручную,
// без ZipArchive: сжатие deflate, если есть zlib, иначе без сжатия.
// При выпуске новых версий этот файл не меняется.

$LIST_FILE = __DIR__ . '/addons.json';
$DATA_DIR  = dirname(__DIR__) . '/data';
$COUNT_FILE = $DATA_DIR . '/addons.php';
$GUARD = "<?php http_response_code(404); exit; ?>\n";
$EXT = ['toc', 'lua', 'xml'];
$MAX_FILES = 200;
$MAX_BYTES = 8 * 1024 * 1024;

function stop($code, $msg) {
    http_response_code($code);
    header('Content-Type: text/plain; charset=utf-8');
    header('Cache-Control: no-store');
    echo $msg;
    exit;
}

function decode_guarded($raw, $guard) {
    if (!$raw) return [];
    if (strpos($raw, $guard) === 0) $raw = substr($raw, strlen($guard));
    $d = json_decode($raw, true);
    return is_array($d) ? $d : [];
}

function read_counts($file, $guard) {
    if (!is_file($file)) return [];
    $fp = @fopen($file, 'r');
    if (!$fp) return [];
    flock($fp, LOCK_SH);
    $raw = stream_get_contents($fp);
    flock($fp, LOCK_UN);
    fclose($fp);
    $d = decode_guarded($raw, $guard);
    return isset($d['counts']) && is_array($d['counts']) ? $d['counts'] : [];
}

// +1 к счётчику. Повторное скачивание с того же IP в течение часа не считаем.
function bump_count($dir, $file, $guard, $id) {
    if (!is_dir($dir) || !is_writable($dir)) return;
    $fp = @fopen($file, 'c+');
    if (!$fp) return;
    flock($fp, LOCK_EX);
    $d = decode_guarded(stream_get_contents($fp), $guard);
    $counts = isset($d['counts']) && is_array($d['counts']) ? $d['counts'] : [];
    $recent = isset($d['recent']) && is_array($d['recent']) ? $d['recent'] : [];
    $now = time();
    foreach ($recent as $k => $t) if ($t < $now - 3600) unset($recent[$k]);
    $ip = isset($_SERVER['REMOTE_ADDR']) ? $_SERVER['REMOTE_ADDR'] : '';
    $key = substr(sha1($id . '|' . $ip . '|' . date('Y-m-d')), 0, 16);
    if (!isset($recent[$key])) {
        $counts[$id] = (isset($counts[$id]) ? (int)$counts[$id] : 0) + 1;
        $recent[$key] = $now;
    }
    ftruncate($fp, 0);
    rewind($fp);
    fwrite($fp, $guard . json_encode(['counts' => $counts, 'recent' => $recent], JSON_UNESCAPED_UNICODE));
    fflush($fp);
    flock($fp, LOCK_UN);
    fclose($fp);
}

// файлы аддона: только нужные расширения, без ссылок, не выходя за папку
function collect($base, $rel, $ext, &$out, $depth, $maxFiles) {
    if ($depth > 4) return;
    $items = @scandir($base . ($rel === '' ? '' : '/' . $rel));
    if (!$items) return;
    sort($items, SORT_STRING);
    foreach ($items as $name) {
        if ($name === '' || $name[0] === '.') continue;
        if (!preg_match('/^[A-Za-z0-9 _().-]+$/', $name)) continue;
        $r = $rel === '' ? $name : $rel . '/' . $name;
        $p = $base . '/' . $r;
        if (is_link($p)) continue;
        if (is_dir($p)) { collect($base, $r, $ext, $out, $depth + 1, $maxFiles); continue; }
        if (!is_file($p)) continue;
        if (!in_array(strtolower(pathinfo($name, PATHINFO_EXTENSION)), $ext, true)) continue;
        if (count($out) >= $maxFiles) return;
        $out[] = $r;
    }
}

function dos_time($ts) {
    $d = getdate($ts);
    if ($d['year'] < 1980) $d = getdate(mktime(0, 0, 0, 1, 1, 1980));
    $time = ($d['hours'] << 11) | ($d['minutes'] << 5) | intdiv($d['seconds'], 2);
    $date = (($d['year'] - 1980) << 9) | ($d['mon'] << 5) | $d['mday'];
    return [$time, $date];
}

// zip вручную: локальные заголовки + центральный каталог (crc32, deflate или store)
function build_zip($files) {
    $zip = '';
    $central = '';
    $n = 0;
    $canDeflate = function_exists('gzdeflate');
    foreach ($files as $name => $f) {
        $data = $f['data'];
        $crc = crc32($data);
        $size = strlen($data);
        $method = 0;
        $body = $data;
        if ($canDeflate && $size > 0) {
            $z = gzdeflate($data, 9);
            if ($z !== false && strlen($z) < $size) { $method = 8; $body = $z; }
        }
        list($t, $d) = dos_time($f['mtime']);
        $offset = strlen($zip);
        $zip .= pack('VvvvvvVVVvv', 0x04034b50, 20, 0x0800, $method, $t, $d, $crc, strlen($body), $size, strlen($name), 0) . $name . $body;
        $central .= pack('VvvvvvvVVVvvvvvVV', 0x02014b50, 20, 20, 0x0800, $method, $t, $d, $crc, strlen($body), $size, strlen($name), 0, 0, 0, 0, $f['dir'] ? 0x10 : 0x20, $offset) . $name;
        $n++;
    }
    $cdOffset = strlen($zip);
    return $zip . $central . pack('VvvvvVVv', 0x06054b50, 0, 0, $n, $n, strlen($central), $cdOffset, 0);
}

// ---------- список аддонов ----------
$list = is_file($LIST_FILE) ? json_decode((string)@file_get_contents($LIST_FILE), true) : null;
$addons = (is_array($list) && isset($list['addons']) && is_array($list['addons'])) ? $list['addons'] : [];

if (isset($_GET['stats'])) {
    $counts = read_counts($COUNT_FILE, $GUARD);
    $res = [];
    foreach ($addons as $a) {
        if (!empty($a['id']) && is_string($a['id'])) $res[$a['id']] = isset($counts[$a['id']]) ? (int)$counts[$a['id']] : 0;
    }
    header('Content-Type: application/json; charset=utf-8');
    header('Cache-Control: no-store');
    echo json_encode(['ok' => true, 'counts' => (object)$res], JSON_UNESCAPED_UNICODE);
    exit;
}

$id = isset($_GET['id']) && is_string($_GET['id']) ? $_GET['id'] : '';
$addon = null;
foreach ($addons as $a) {
    if (isset($a['id']) && is_string($a['id']) && $a['id'] !== '' && hash_equals($a['id'], $id)) { $addon = $a; break; }
}
if (!$addon) stop(404, 'Такого аддона нет. Вернись на страницу аддонов: addons.html');

$folder = isset($addon['folder']) && is_string($addon['folder']) ? $addon['folder'] : '';
$version = isset($addon['version']) && is_string($addon['version']) ? $addon['version'] : '';
if (!preg_match('/^[A-Za-z0-9_-]{1,64}$/', $folder)) stop(500, 'В addons.json неверное имя папки аддона.');
if (!preg_match('/^[0-9A-Za-z.\-]{1,32}$/', $version)) $version = 'latest';

$base = realpath(__DIR__ . '/' . $folder);
if ($base === false || !is_dir($base) || dirname($base) !== realpath(__DIR__)) stop(404, 'Файлы аддона не найдены на сервере.');

$rels = [];
collect($base, '', $EXT, $rels, 0, $MAX_FILES);
if (!$rels) stop(404, 'В папке аддона нет файлов.');

$files = [];
$total = 0;
$dirs = [];
foreach ($rels as $r) {
    $p = $base . '/' . $r;
    $data = @file_get_contents($p);
    if ($data === false) stop(500, 'Не получилось прочитать файлы аддона.');
    $total += strlen($data);
    if ($total > $MAX_BYTES) stop(500, 'Аддон слишком большой для сборки на лету.');
    // записи папок, чтобы архив одинаково распаковывался во всех программах
    $parts = explode('/', $r);
    for ($i = 0; $i < count($parts) - 1; $i++) $dirs[implode('/', array_slice($parts, 0, $i + 1))] = true;
    $files[$folder . '/' . $r] = ['data' => $data, 'mtime' => (int)@filemtime($p), 'dir' => false];
}
$entries = [$folder . '/' => ['data' => '', 'mtime' => (int)@filemtime($base), 'dir' => true]];
foreach (array_keys($dirs) as $dname) $entries[$folder . '/' . $dname . '/'] = ['data' => '', 'mtime' => (int)@filemtime($base . '/' . $dname), 'dir' => true];
$entries += $files;

$zip = build_zip($entries);
$fileName = $folder . '-' . $version . '.zip';

if ($_SERVER['REQUEST_METHOD'] !== 'HEAD') bump_count($DATA_DIR, $COUNT_FILE, $GUARD, $addon['id']);

header('Content-Type: application/zip');
header('Content-Disposition: attachment; filename="' . $fileName . '"');
header('Content-Length: ' . strlen($zip));
header('Cache-Control: no-store');
header('X-Content-Type-Options: nosniff');
echo $zip;
