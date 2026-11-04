#!/usr/bin/env python3
"""Сборка выпусков Forever. Запуск из корня репозитория:
  python3 agent/tools/vypusk.py addon <Папка аддона> <куда положить>
      zip для игры; если аддон есть в site/addons/addons.json, ещё и пакет для сайта.
  python3 agent/tools/vypusk.py site <куда положить> <файл от agent/site> [<файл> ...]
      пакет для сайта из перечисленных файлов.
Пакет для сайта повторяет public_html. config.php, data/ и установочные тексты в него не попадают никогда."""
import json,pathlib,re,shutil,sys,zipfile
ROOT=pathlib.Path(__file__).resolve().parents[1]; ADD=ROOT/"addons"; SITE=ROOT/"site"
EXT={".toc",".lua",".xml"}
def die(m): sys.exit("СТОП: "+m)
def toc_version(d):
    t=next(d.glob("*.toc"),None)
    if not t: die(f"нет .toc в {d}")
    m=re.search(r"^## Version:\s*(\S+)",t.read_text(encoding="utf8"),re.M)
    if not m: die("нет ## Version в .toc")
    return m.group(1)
def addon(name,out):
    d=ADD/name
    if not d.is_dir(): die(f"нет аддона {name}")
    v=toc_version(d); out.mkdir(parents=True,exist_ok=True)
    files=[f for f in sorted(d.rglob("*")) if f.is_file() and f.suffix.lower() in EXT]
    z1=out/f"{name}-{v}.zip"
    with zipfile.ZipFile(z1,"w",zipfile.ZIP_DEFLATED) as z:
        for f in files: z.write(f,f"{name}/{f.relative_to(d).as_posix()}")
    print("для игры:",z1,len(files),"файлов")
    lst=SITE/"addons/addons.json"; j=json.loads(lst.read_text(encoding="utf8"))
    a=next((x for x in j["addons"] if x["folder"]==name),None)
    if not a: print("на сайте этого аддона нет: пакет для сайта не собран"); return
    if a["version"]!=v: die(f"версия в .toc {v}, в addons.json {a['version']}: обнови addons.json")
    if not a.get("changelog") or a["changelog"][0][0]!=v: die(f"нет записи {v} первой в changelog")
    dst=SITE/"addons"/name
    if dst.exists(): shutil.rmtree(dst)
    for f in files:
        p=dst/f.relative_to(d); p.parent.mkdir(parents=True,exist_ok=True); shutil.copy2(f,p)
    z2=out/f"site_{name}-{v}.zip"
    with zipfile.ZipFile(z2,"w",zipfile.ZIP_DEFLATED) as z:
        z.write(lst,"addons/addons.json")
        for f in files: z.write(dst/f.relative_to(d),f"addons/{name}/{f.relative_to(d).as_posix()}")
    print("для сайта:",z2)
def site(out,names):
    out.mkdir(parents=True,exist_ok=True); z2=out/"site_update.zip"
    for n in names:
        if n=="config.php" or n.startswith("data/") or n.endswith(".txt") or ".." in n: die(f"этот файл на сайт не выкладываем: {n}")
        if not (SITE/n).is_file(): die(f"нет файла {n}")
    with zipfile.ZipFile(z2,"w",zipfile.ZIP_DEFLATED) as z:
        for n in names: z.write(SITE/n,n)
    print("для сайта:",z2,len(names),"файлов")
if len(sys.argv)>=4 and sys.argv[1]=="addon": addon(sys.argv[2],pathlib.Path(sys.argv[3]))
elif len(sys.argv)>=4 and sys.argv[1]=="site": site(pathlib.Path(sys.argv[2]),sys.argv[3:])
else: sys.exit(__doc__)
