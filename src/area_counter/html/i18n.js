// Язык интерфейса окон — как в RALNCS. tools\build_rbz.ps1 -Lang en подменяет первую строку.
var LANG = 'ru';

var I18N = {
  ru: {
    // ---- окно area counter: шапка ----
    btn_run: 'Посчитать',
    btn_hi: 'Подсветить',
    hi_title: 'Обвести во вьюпорте посчитанное; при сечении — нарисовать его контур. Esc — выключить',
    btn_copy: 'Скопировать',
    btn_copy_n: 'Скопировать: {what} ({n})',
    copy_title: 'Таблица выбранного уровня в буфер: вставляется в Google Таблицы и Excel готовыми колонками',
    btn_export: 'Вывод сечений',
    export_title: 'Создать в модели плоские грани сечения по внешнему контуру этажей — площадь видна в Entity Info. Отмена — Ctrl+Z',
    only_bad: 'только проблемные',
    only_bad_title: 'Показать только этажи, площади которых нельзя верить',
    btn_fold: 'Свернуть всё',
    btn_unfold: 'Развернуть всё',
    fold_title: 'Свернуть или развернуть все корпуса и комплексы',
    btn_help: 'Инструкция',

    help_html:
      '<h3>Что выделено</h3>' +
      '<p>На сколько уровней вниз от выделенного лежат этажи. Выделили сами этажи — «Этажи», ' +
      'выделили корпус — «Корпус», комплекс — «Комплекс». Плагин не знает слов «этаж» и «корпус», ' +
      'для него это число уровней. Каждый этаж считается целиком, со всем, что внутри него вложено. ' +
      'Если вложенности меньше заявленной, выделенное само становится этажом.</p>' +
      '<h3>Верхняя грань</h3>' +
      '<p>Быстрый счёт по всем горизонтальным граням верхней отметки. Уступ наверху не съедает ' +
      'площадь, повёрнутые оси группы не мешают.</p>' +
      '<h3>Сечение</h3>' +
      '<p>Горизонтальный разрез этажа на заданной высоте от его низа (по умолчанию 1000 мм). ' +
      'Площадь — по <b>внешнему контуру</b>, включая всю пластику и окна: край точно повторяет ' +
      'фасад, без срезанных углов и усреднений. Нужен для пирамидального массинга, где верхняя ' +
      'грань меньше нижней. Модель при расчёте не меняется.</p>' +
      '<p><b>Сварка точек</b> (1 мм) — концы ближе этого считаются одной точкой. ' +
      '<b>Зазоры</b> (20 мм) — щели между кусками фасада уже этого закрываются: пилястра в 5 мм ' +
      'от стены войдёт в контур. Щель шире — нет.</p>' +
      '<p>Если рез попал ровно на плиту или подоконник, он сам сдвигается на 2 мм вверх. Если на ' +
      'заданной высоте кольцо фасада разорвано (открытый проём без стекла), плагин перебирает ' +
      'высоты и берёт первую, где контур цел, — какую именно, написано в статусе этажа.</p>' +
      '<p><b>Внутренние дворы</b> по умолчанию не вычитаются — площадь по внешнему контуру. ' +
      'Галочка «вычитать дворы» включает вычет: двором считается внутренний контур, стены которого ' +
      'смотрят внутрь него; колонны и шахты-солиды не вычитаются.</p>' +
      '<p>Куски, лежащие отдельно от основного контура (больше 0,1 м²), в площадь этажа не входят — ' +
      'о них сказано в статусе, в модели они получают свои грани.</p>' +
      '<h3>Статусы</h3>' +
      '<p>Зелёный «посчитано» — площади можно верить. Оранжевый — посчитано, но есть оговорка ' +
      '(сдвинута высота, найдены отдельные фрагменты) — она в самой таблетке. Красный — площади ' +
      'верить нельзя, причина там же. Галочка «только проблемные» оставляет в таблице красные.</p>' +
      '<h3>Подсветить</h3>' +
      '<p>Обводит во вьюпорте габариты посчитанного (зелёным) и проблемного (оранжевым). При ' +
      'сечении рисует его контур зелёным, а отрезки, которые не сошлись в контур, — оранжевым: ' +
      'видно, где именно разрыв. Esc во вьюпорте — выключить.</p>' +
      '<h3>Клик по строке</h3>' +
      '<p>Наводит камеру на объект и выделяет его. Точку орбиты SketchUp кладёт чуть дальше ' +
      'объекта — после зума орбита крутится не ровно вокруг него.</p>' +
      '<h3>Скопировать</h3>' +
      '<p>Таблица выбранного уровня уходит в буфер сразу текстом и HTML — вставляется в Google ' +
      'Таблицы и Excel готовыми колонками. Числа с запятой. «Этажи» — для проверки, «Корпуса» и ' +
      '«Комплексы» — рабочие; площади старших уровней есть в тех же строках.</p>' +
      '<h3>Вывод сечений</h3>' +
      '<p>Кладёт сечения в модель: в корне — группа «area counter: сечения» на теге ' +
      '«AC_Сечения», внутри та же иерархия, что в таблице (комплекс → корпус → этаж). В группе ' +
      'этажа — одна плоская грань по внешнему контуру на высоте реза; кликните по ней — Entity ' +
      'Info покажет площадь. Повторный запуск заменяет прежнее сечение того же этажа, а не ' +
      'добавляет второе. Исходные этажи не меняются. Одной операцией: Ctrl+Z убирает целиком. ' +
      'Работает после счёта способом «Сечение».</p>' +
      '<h3>Один этаж</h3>' +
      '<p>То же для одного этажа без окна: меню Расширения → area counter → «Сечение этажа…». ' +
      'Выделите ровно одну группу-этаж — плагин спросит параметры, построит грань и покажет ' +
      'площадь.</p>' +
      '<h3>О плагине</h3>' +
      '<p>Меню Расширения → area counter → «О плагине…» — версия, авторы и ссылка на репозиторий.</p>',

    status_hint: 'Выделите корпус, комплекс или сами этажи и нажмите «Посчитать».',
    counting: 'Считаю…',
    st_floors: 'Этажей: {n}',
    st_problems: ' (проблемных {n})',
    st_area: ' • площадь {a} м² • ',
    st_spent: ' • {s} с',
    how_section: 'сечение на {mm} мм от низа этажа',
    how_top: 'по верхней грани',
    shifted_one: ' (у этажа высота подобрана другая — см. статус)',
    shifted_n: ' (у {n} из {m} высота подобрана другая — см. статус)',

    // ---- таблица ----
    th_object: 'Объект',
    th_level: 'Уровень',
    th_floors: 'Этажей',
    th_area: 'Площадь, м²',
    th_status: 'Статус',
    empty: 'Ничего ещё не посчитано.',
    empty_bad: 'Проблемных этажей нет.',
    zoom_title: ' — навести камеру',
    pill_ok: 'посчитано',
    pill_problem: 'проблема',
    pill_bad_title: 'Площади этого этажа верить нельзя',
    pill_warn_title: 'Посчитано, но с оговоркой — она в самой таблетке',

    // ---- настройки сбоку ----
    side_selected: 'Что выделено',
    lvl_floors: 'Этажи',
    lvl_block: 'Корпус',
    lvl_complex: 'Комплекс',
    side_method: 'Способ',
    m_top: 'Верхняя грань',
    m_section: 'Сечение',
    f_offset: 'Высота реза от низа этажа, мм',
    f_gap: 'Закрывать зазоры до, мм',
    f_snap: 'Сварка точек, мм',
    hidden_lbl: 'пропускать скрытое',
    hidden_title: 'Скрытые объекты и выключенные теги в сечение не попадают',
    holes_lbl: 'вычитать дворы',
    holes_title: 'Вычитать внутренние дворы и атриумы из площади этажа',
    side_copy: 'Копировать',
    c_floors: 'Этажи — для проверки',
    c_blocks: 'Корпуса',
    c_complexes: 'Комплексы',
    pl_floors: 'Этажи',
    pl_blocks: 'Корпуса',
    pl_complexes: 'Комплексы',
    side_hint: 'Этажи лежат на выбранной глубине под выделенным и считаются целиком. Настройки запоминаются.',
    btn_reset: 'Сбросить',
    footer: 'Сечение — по внешнему контуру, включая пластику и окна; щели уже заданного зазора ' +
            'закрываются, дворы по умолчанию не вычитаются. Подробнее — «Инструкция». Площади в м², ' +
            'числа с запятой.',

    // ---- сообщения ----
    copy_first: 'Сначала посчитайте — копировать пока нечего.',
    toast_copied: 'Скопировано: {r} строк × {c} столбцов. Вставьте в Google Таблицу (Ctrl+V).',
    confirm_export: 'Создать в модели грани сечения, этажей: {n}?',
    confirm_export_where: 'Появится группа «area counter: сечения» на теге AC_Сечения с той же иерархией. ' +
                          'Прежние сечения этих этажей будут заменены.',
    confirm_undo: 'Действие можно отменить (Ctrl+Z).',
    btn_create: 'Создать',
    btn_cancel: 'Отмена',

    // ---- о плагине ----
    about_title: 'О плагине area counter',
    about_desc: 'Площади этажей, корпусов и комплексов по верхней грани или по сечению, таблица в буфер для Google Таблиц / Excel и грани сечений в модели.',
    about_authors: 'Авторы',
    about_names: 'Ruslan Tkachenko и Maksar Sanjeev',
    about_ver: 'версия ',
    about_lic: 'Apache 2.0 · B&A community',
    btn_close: 'Закрыть'
  },

  en: {
    btn_run: 'Calculate',
    btn_hi: 'Highlight',
    hi_title: 'Outline the results in the viewport; for a section, draw its contour. Esc to turn off',
    btn_copy: 'Copy',
    btn_copy_n: 'Copy: {what} ({n})',
    copy_title: 'Table of the chosen level to the clipboard: pastes into Google Sheets and Excel as ready columns',
    btn_export: 'Output sections',
    export_title: 'Create flat section faces along the outer contour of the floors — the area shows in Entity Info. Undo — Ctrl+Z',
    only_bad: 'problems only',
    only_bad_title: 'Show only floors whose area cannot be trusted',
    btn_fold: 'Collapse all',
    btn_unfold: 'Expand all',
    fold_title: 'Collapse or expand all buildings and complexes',
    btn_help: 'Guide',

    help_html:
      '<h3>What is selected</h3>' +
      '<p>How many levels below the selection the floors are. Selected the floors themselves — “Floors”, ' +
      'a building — “Building”, a complex — “Complex”. The plugin does not know the words “floor” or ' +
      '“building”: to it this is a number of levels. Each floor is counted as a whole, with everything ' +
      'nested inside it. If the nesting is shallower than chosen, the selection itself becomes a floor.</p>' +
      '<h3>Top face</h3>' +
      '<p>Fast count over all horizontal faces at the top elevation. A setback at the top does not eat ' +
      'into the area, rotated group axes do not matter.</p>' +
      '<h3>Section</h3>' +
      '<p>A horizontal cut through the floor at the given height above its bottom (1000 mm by default). ' +
      'The area follows the <b>outer contour</b>, including all facade relief and windows: the edge ' +
      'follows the facade exactly, with no clipped corners or averaging. Use it for stepped or pyramid ' +
      'massing where the top face is smaller than the bottom. The model is not changed by the calculation.</p>' +
      '<p><b>Point weld</b> (1 mm) — ends closer than this count as one point. ' +
      '<b>Gaps</b> (20 mm) — slots between facade pieces narrower than this are closed: a pilaster 5 mm ' +
      'off the wall joins the contour. A wider gap does not.</p>' +
      '<p>If the cut lands exactly on a slab or a sill, it moves 2 mm up by itself. If the facade ring is ' +
      'broken at the given height (an open doorway without glazing), the plugin tries other heights and ' +
      'takes the first one where the contour is whole — which one is written in the floor status.</p>' +
      '<p><b>Inner courtyards</b> are not subtracted by default — the area is by the outer contour. ' +
      'The “subtract courtyards” box turns subtraction on: a courtyard is an inner contour whose walls ' +
      'face into it; columns and solid shafts are not subtracted.</p>' +
      '<p>Pieces lying apart from the main contour (over 0.1 m²) are not included in the floor area — ' +
      'the status mentions them, and in the model they get faces of their own.</p>' +
      '<h3>Statuses</h3>' +
      '<p>Green “calculated” — the area can be trusted. Orange — calculated with a caveat (height moved, ' +
      'separate fragments found), shown in the pill itself. Red — the area cannot be trusted, the reason ' +
      'is in the pill. The “problems only” box leaves only the red ones in the table.</p>' +
      '<h3>Highlight</h3>' +
      '<p>Outlines the bounding boxes of the results in the viewport: calculated in green, problem ' +
      'floors in orange. For a section it draws its contour in green and the segments that did not close ' +
      'into it in orange — you can see exactly where the gap is. Esc in the viewport turns it off.</p>' +
      '<h3>Click a row</h3>' +
      '<p>Zooms the camera to the object and selects it. SketchUp puts the orbit point slightly behind ' +
      'the object, so after zooming the orbit does not spin exactly around it.</p>' +
      '<h3>Copy</h3>' +
      '<p>The table of the chosen level goes to the clipboard as text and HTML at once — pastes into ' +
      'Google Sheets and Excel as ready columns. Numbers use a decimal point. “Floors” is for checking, ' +
      '“Buildings” and “Complexes” are the working tables; areas of the upper levels are in the same rows.</p>' +
      '<h3>Output sections</h3>' +
      '<p>Puts the sections into the model: at the root, a group “area counter: sections” on the ' +
      '“AC_Sections” tag, with the same hierarchy as the table inside (complex → building → floor). ' +
      'A floor group holds one flat face along the outer contour at the cut height; click it and ' +
      'Entity Info shows the area. Running again replaces the previous section of the same floor instead ' +
      'of adding a second one. The source floors are not changed. One operation: Ctrl+Z removes it all. ' +
      'Works after calculating with the “Section” method.</p>' +
      '<h3>A single floor</h3>' +
      '<p>The same for one floor without the window: Extensions → area counter → “Floor section…”. ' +
      'Select exactly one floor group — the plugin asks for the parameters, builds the face and shows ' +
      'the area.</p>' +
      '<h3>About</h3>' +
      '<p>Extensions → area counter → “About…” — version, authors and a link to the repository.</p>',

    status_hint: 'Select a building, a complex or the floors themselves and click “Calculate”.',
    counting: 'Calculating…',
    st_floors: 'Floors: {n}',
    st_problems: ' ({n} with problems)',
    st_area: ' • area {a} m² • ',
    st_spent: ' • {s} s',
    how_section: 'section at {mm} mm above floor bottom',
    how_top: 'by top face',
    shifted_one: ' (the floor used another height — see status)',
    shifted_n: ' ({n} of {m} used another height — see status)',

    th_object: 'Object',
    th_level: 'Level',
    th_floors: 'Floors',
    th_area: 'Area, m²',
    th_status: 'Status',
    empty: 'Nothing calculated yet.',
    empty_bad: 'No problem floors.',
    zoom_title: ' — zoom to it',
    pill_ok: 'calculated',
    pill_problem: 'problem',
    pill_bad_title: 'The area of this floor cannot be trusted',
    pill_warn_title: 'Calculated, with a caveat — it is in the pill itself',

    side_selected: 'What is selected',
    lvl_floors: 'Floors',
    lvl_block: 'Building',
    lvl_complex: 'Complex',
    side_method: 'Method',
    m_top: 'Top face',
    m_section: 'Section',
    f_offset: 'Cut height above floor bottom, mm',
    f_gap: 'Close gaps up to, mm',
    f_snap: 'Point weld, mm',
    hidden_lbl: 'skip hidden',
    hidden_title: 'Hidden objects and tags turned off do not get into the section',
    holes_lbl: 'subtract courtyards',
    holes_title: 'Subtract inner courtyards and atriums from the floor area',
    side_copy: 'Copy',
    c_floors: 'Floors — for checking',
    c_blocks: 'Buildings',
    c_complexes: 'Complexes',
    pl_floors: 'Floors',
    pl_blocks: 'Buildings',
    pl_complexes: 'Complexes',
    side_hint: 'Floors lie at the chosen depth under the selection and are counted as a whole. Settings are remembered.',
    btn_reset: 'Reset',
    footer: 'Section — by the outer contour, including facade relief and windows; gaps narrower than ' +
            'the set value are closed, courtyards are not subtracted by default. More — “Guide”. ' +
            'Areas in m², decimal point.',

    copy_first: 'Calculate first — nothing to copy yet.',
    toast_copied: 'Copied: {r} rows × {c} columns. Paste into Google Sheets (Ctrl+V).',
    confirm_export: 'Create section faces in the model for {n} floor(s)?',
    confirm_export_where: 'A group “area counter: sections” on the AC_Sections tag will appear with the same ' +
                          'hierarchy. Previous sections of these floors will be replaced.',
    confirm_undo: 'This can be undone (Ctrl+Z).',
    btn_create: 'Create',
    btn_cancel: 'Cancel',

    about_title: 'About area counter',
    about_desc: 'Floor, building and complex areas by top face or by section, a table for Google Sheets / Excel via the clipboard, and section faces in the model.',
    about_authors: 'Authors',
    about_names: 'Ruslan Tkachenko and Maksar Sanjeev',
    about_ver: 'version ',
    about_lic: 'Apache 2.0 · B&A community',
    btn_close: 'Close'
  }
};

var T = I18N[LANG] || I18N.ru;
function t(key) { var s = T[key]; return s === undefined ? (I18N.ru[key] === undefined ? key : I18N.ru[key]) : s; }
// tf('st_floors', {n: 3}) — подстановка {плейсхолдеров}
function tf(key, vars) {
  return t(key).replace(/\{(\w+)\}/g, function (_, k) { return vars[k] !== undefined ? vars[k] : '{' + k + '}'; });
}
// Разметка держит русский текст как запасной; data-t / data-t-title / data-t-ph переводят на месте,
// data-t-html — блоки с разметкой внутри (инструкция)
function applyLang() {
  document.documentElement.lang = LANG;
  document.querySelectorAll('[data-t]').forEach(function (el) { el.textContent = t(el.getAttribute('data-t')); });
  document.querySelectorAll('[data-t-title]').forEach(function (el) { el.title = t(el.getAttribute('data-t-title')); });
  document.querySelectorAll('[data-t-ph]').forEach(function (el) { el.placeholder = t(el.getAttribute('data-t-ph')); });
  document.querySelectorAll('[data-t-html]').forEach(function (el) { el.innerHTML = t(el.getAttribute('data-t-html')); });
  var title = document.querySelector('title[data-t]');
  if (title) document.title = t(title.getAttribute('data-t'));
}
