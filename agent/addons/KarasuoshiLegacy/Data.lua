-- Karasuoshi Legacy: данные плана.
-- Правится здесь; формат совпадает с черновиком-примерочной (страница Karasuoshi Legacy).
local ADDON, ns = ...

-- Персонажи плана: ключ -> имя в игре (первое слово имени, без фамилии)
ns.ROSTER = {
    osh   = { name = "Osh",   short = "Osh" },
    ebosh = { name = "Ebosh", short = "Ebosh" },
}
ns.ROSTER_ORDER = { "osh", "ebosh" }

-- Профессии плана: ключ -> чей и как называется в клиенте (ru и en).
-- string.lower в WoW не трогает кириллицу, поэтому русские названия пишем как в клиенте.
ns.PROFS = {
    lw   = { who = "osh",   label = "Кожевничество",   names = { "Кожевничество", "кожевничество", "Leatherworking" } },
    tail = { who = "ebosh", label = "Портняжное дело", names = { "Портняжное дело", "портняжное дело", "Tailoring" } },
    ench = { who = "ebosh", label = "Наложение чар",   names = { "Наложение чар", "наложение чар", "Enchanting" } },
}
ns.PROF_ORDER = { "lw", "tail", "ench" }

-- Этапы. auto: {who=, level=} | {skill=, min=} | {skills={tail=225, ench=225}} | {dungeon=}
ns.STAGES = {
    { key = "s0", title = "Подготовка", groups = {
        { who = "all", steps = {
            { t = "Пак пришёл и активирован на нужную WoW-учётку" },
            { t = "Созданы Osh и Ebosh Karasuoshi: Орда, PvP" },
            { t = "Игровое время TR активно" },
            { t = "Аутентификатор Battle.net и SMS-уведомления" },
            { t = "Аддоны: RestedXP, Questie, Guidelime + TUGs, Dungeon Quests Forever, Auctionator, Rested Buff" },
        } },
    } },
    { key = "s1", title = "Ebosh 1 → 10", groups = {
        { who = "ebosh", steps = {
            { t = "Тирисфальские леса по маршруту RestedXP", auto = { who = "ebosh", level = 6 } },
            { t = "Квест на сумку стартовой зоны", n = "Сумка привязывается при получении, делать самому" },
            { t = "Выучить портняжное дело и наложение чар", auto = { skill = "tail", min = 1 } },
            { t = "Шить Linen Bag: себе и Osh", n = "Рецепт делает две сумки за раз" },
            { t = "10 уровень: Journeyman в обеих профессиях", auto = { who = "ebosh", level = 10 } },
            { t = "Дойти в Undercity и выйти в городе" },
        } },
    } },
    { key = "s2", title = "Osh 1 → 14", levels = { 1, 13 }, groups = {
        { who = "osh", steps = {
            { t = "Маршрут RestedXP до 14", auto = { who = "osh", level = 14 } },
            { t = "Снятие шкур, кожевничество, кулинария, первая помощь", auto = { skill = "lw", min = 1 } },
            { t = "5 уровень: квест The Great Outdoors, открывает костёр", auto = { who = "osh", level = 6 } },
            { t = "Таланты с 10: Wand Specialization 2/2, затем Spirit Tap", auto = { who = "osh", level = 11 } },
            { t = "Кожевничество 20: первая Camp Tent", n = "5 Light Leather, нужен костёр рядом", auto = { skill = "lw", min = 20 } },
            { t = "Ткань, шкуры, зелёные и BoE уходят почтой Ebosh" },
        } },
        { who = "ebosh", steps = {
            { t = "Наложение чар 10: Lesser Magic Wand для Osh", auto = { skill = "ench", min = 10 } },
            { t = "Сумки Osh, пока у него пустые слоты" },
        } },
    } },
    { key = "s3", title = "Osh 14 → 22", levels = { 14, 21 }, groups = {
        { who = "osh", steps = {
            { t = "14 уровень: цепочка Cozy Sleeping Bag", n = "Barrens, южнее Camp Taurajo" },
            { t = "Заранее взять квесты Ragefire и Wailing Caverns", n = "Hidden Enemies, The Power to Destroy, The Forgotten Pools, Raptor Horns" },
            { t = "Ragefire Chasm на 14, все квесты за одну ходку", auto = { dungeon = "rfc" } },
            { t = "Ruins of Lordaeron с 16", n = "Witherfang, The Baron, Crest of Lordaeron" },
            { t = "Wailing Caverns: четыре квеста за одну ходку", auto = { dungeon = "wc" } },
            { t = "22: дальше Guidelime + TUGs", auto = { who = "osh", level = 22 } },
        } },
        { who = "ebosh", steps = {
            { t = "Greater Magic Wand для Osh к его 13 уровню" },
            { t = "Смена: Ebosh 10 → 15", auto = { who = "ebosh", level = 15 } },
            { t = "Портняжное дело 150: очко Легаси", auto = { skill = "tail", min = 150 } },
            { t = "Наложение чар 150: очко Легаси", auto = { skill = "ench", min = 150 } },
        } },
    } },
    { key = "s4", title = "Osh 22 → 30", levels = { 22, 29 }, groups = {
        { who = "osh", steps = {
            { t = "Shadowfang Keep: после Arugal забрать Black Tome", auto = { dungeon = "sfk" } },
            { t = "Hillsbrad до 23", n = "Спорная зона: лагерь в стороне от дорог" },
            { t = "BFD: сапфиры и Damp Note до входа, внутри Fathom Core", auto = { dungeon = "bfd" } },
            { t = "25 уровень: очко Легаси за класс", auto = { who = "osh", level = 25 } },
            { t = "Кожевничество 150: очко Легаси", auto = { skill = "lw", min = 150 } },
            { t = "Excavation Site: Wetlands, 26–31" },
            { t = "City of Dalaran с Tome of Dalaran: босс Lyn the Ignored" },
        } },
        { who = "ebosh", steps = {
            { t = "Смена: Ebosh 15 → 20, Expert в обеих профессиях", auto = { who = "ebosh", level = 20 } },
        } },
    } },
    { key = "s5", title = "Osh 30 → 40", levels = { 30, 39 }, groups = {
        { who = "osh", steps = {
            { t = "Thousand Needles, Desolace, Arathi, STV" },
            { t = "Кожевничество 225", auto = { skill = "lw", min = 225 } },
            { t = "40: верховая езда (100 з.) и респек в Shadow", auto = { who = "osh", level = 40 } },
        } },
        { who = "ebosh", steps = {
            { t = "Смена: Ebosh 20 → 25, очко Легаси за класс", auto = { who = "ebosh", level = 25 } },
            { t = "Переезд в Оргриммар" },
            { t = "Портняжное дело и наложение чар 225", auto = { skills = { tail = 225, ench = 225 } } },
        } },
    } },
    { key = "s6", title = "Osh 40 → 60", levels = { 40, 60 }, groups = {
        { who = "osh", steps = {
            { t = "Riverglades, Tanaris, Feralas, Hinterlands, Badlands" },
            { t = "45 уровень: очко Легаси", auto = { who = "osh", level = 45 } },
            { t = "Кожевничество 300: очко Легаси", auto = { skill = "lw", min = 300 } },
            { t = "Un'Goro, Felwood, Burning Steppes, Winterspring, EPL" },
            { t = "60 уровень: очко Легаси", auto = { who = "osh", level = 60 } },
        } },
    } },
}

-- Квесты подземелий. id из Classic, после запуска сверить; если id не совпал,
-- статус «в журнале» всё равно ищется по названию.
-- zones: где показывать мелкую строку «данж рядом» (названия зон ru/en)
ns.DUNGEONS = {
    { key = "rfc", name = "Ragefire Chasm", min = 13, max = 18,
      zones = { "Оргриммар", "Orgrimmar" },
      quests = {
        { id = 5726, title = "Hidden Enemies", where = "Тралл, Оргриммар" },
        { id = 5725, title = "The Power to Destroy...", where = "Undercity" },
      } },
    { key = "wc", name = "Wailing Caverns", min = 15, max = 25,
      zones = { "Степи", "The Barrens", "Северные Степи", "Northern Barrens" },
      quests = {
        { id = 914,  title = "Leaders of the Fang", where = "цепочка The Forgotten Pools" },
        { id = 1491, title = "Smart Drinks", where = "цепочка Raptor Horns" },
        { id = 959,  title = "Trouble at the Docks", where = "Ratchet" },
        { id = 1487, title = "Deviate Eradication", where = "оазис у входа" },
      } },
    { key = "sfk", name = "Shadowfang Keep", min = 18, max = 25,
      zones = { "Серебряный бор", "Silverpine Forest" },
      quests = {
        { item = 276561, title = "Black Tome", where = "стол после Arugal" },
      } },
    { key = "bfd", name = "Blackfathom Deeps", min = 22, max = 30,
      zones = { "Ясеневый лес", "Ashenvale" },
      quests = {
        { id = 6563, title = "The Essence of Aku'Mai", where = "сапфиры до входа" },
        { id = 6564, title = "Allegiance to the Old Gods", where = "Damp Note до входа" },
        { id = 6921, title = "Amongst the Ruins", where = "Fathom Core внутри" },
      } },
}

-- Novice Spelunker (одно очко Легаси на аккаунт): шесть подземелий 15–25
ns.SPELUNKER_ACHIEVEMENT = 62031
ns.SPELUNKER = {
    { key = "rfc", name = "Ragefire Chasm" },
    { key = "wc",  name = "Wailing Caverns" },
    { key = "sfk", name = "Shadowfang Keep" },
    { key = "rol", name = "Ruins of Lordaeron" },
    { key = "dm",  name = "The Deadmines" },
    { key = "exc", name = "Excavation Site: Wetlands" },
}

-- Пороги подсказок
ns.LIMITS = {
    wandLag   = 6,    -- палочка отстала на столько уровней
    mailItems = 15,   -- вещей в сумках / писем в ящике
    restLow   = 5,    -- рестед ниже этого, % уровня
    restGap   = 50,   -- у второго больше на столько %, предлагаем переключиться
}
