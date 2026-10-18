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
    only_bad: 'только проблемные',
    only_bad_title: 'Показать только этажи, площади которых нельзя верить',

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
    fold_title: 'Свернуть или развернуть все строки',
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
    tip_depth0: 'Выделены сами этажи',
    tip_depth1: 'Выделен корпус: этажи — группы внутри него',
    tip_depth2: 'Выделен комплекс: внутри корпуса, в них этажи',
    side_method: 'Способ',
    m_top: 'Верхняя грань',
    m_section: 'Сечение',
    tip_top: 'Быстро: по горизонтальным граням верхней отметки этажа',
    tip_section: 'Горизонтальный разрез этажа: площадь по внешнему контуру, с пластикой и окнами',
    f_offset: 'Отметка от низа этажа, мм',
    tip_offset: 'Где резать этаж. Попал рез на плиту — сдвинется на 2 мм; разорван проёмом — плагин подберёт другую отметку и напишет её в статусе',
    side_copy: 'Копировать',
    c_floors: 'Этажи — для проверки',
    c_blocks: 'Корпуса',
    c_complexes: 'Комплексы',
    pl_floors: 'Этажи',
    pl_blocks: 'Корпуса',
    pl_complexes: 'Комплексы',
    side_hint: 'Этажи лежат на выбранной глубине под выделенным и считаются целиком. Настройки запоминаются.',
    btn_reset: 'Сбросить',
    footer: 'Сечение — по внешнему контуру, включая пластику и окна; щели до 20 мм закрываются, ' +
            'дворы не вычитаются. Площади в м², числа с запятой.',

    // ---- сообщения ----
    copy_first: 'Сначала посчитайте — копировать пока нечего.',
    toast_copied: 'Скопировано: {r} строк × {c} столбцов. Вставьте в Google Таблицу (Ctrl+V).',

    // ---- о плагине ----
    about_title: 'О плагине area counter',
    about_desc: 'Площади этажей, корпусов и комплексов по верхней грани или по сечению, таблица в буфер для Google Таблиц / Excel.',
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
    only_bad: 'problems only',
    only_bad_title: 'Show only floors whose area cannot be trusted',

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
    fold_title: 'Collapse or expand all rows',
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
    tip_depth0: 'The floors themselves are selected',
    tip_depth1: 'A building is selected: the floors are groups inside it',
    tip_depth2: 'A complex is selected: buildings inside it, floors inside them',
    side_method: 'Method',
    m_top: 'Top face',
    m_section: 'Section',
    tip_top: 'Fast: by the horizontal faces at the top elevation of the floor',
    tip_section: 'A horizontal cut through the floor: area by the outer contour, with facade relief and windows',
    f_offset: 'Height above floor bottom, mm',
    tip_offset: 'Where to cut the floor. If the cut lands on a slab it moves 2 mm; if a doorway breaks the ring, the plugin picks another height and writes it in the status',
    side_copy: 'Copy',
    c_floors: 'Floors — for checking',
    c_blocks: 'Buildings',
    c_complexes: 'Complexes',
    pl_floors: 'Floors',
    pl_blocks: 'Buildings',
    pl_complexes: 'Complexes',
    side_hint: 'Floors lie at the chosen depth under the selection and are counted as a whole. Settings are remembered.',
    btn_reset: 'Reset',
    footer: 'Section — by the outer contour, including facade relief and windows; gaps up to 20 mm are closed, ' +
            'courtyards are not subtracted. Areas in m², decimal point.',

    copy_first: 'Calculate first — nothing to copy yet.',
    toast_copied: 'Copied: {r} rows × {c} columns. Paste into Google Sheets (Ctrl+V).',

    about_title: 'About area counter',
    about_desc: 'Floor, building and complex areas by top face or by section, a table for Google Sheets / Excel via the clipboard.',
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
// Разметка держит русский текст как запасной; data-t / data-t-title / data-t-ph переводят на месте
function applyLang() {
  document.documentElement.lang = LANG;
  document.querySelectorAll('[data-t]').forEach(function (el) { el.textContent = t(el.getAttribute('data-t')); });
  document.querySelectorAll('[data-t-title]').forEach(function (el) { el.title = t(el.getAttribute('data-t-title')); });
  document.querySelectorAll('[data-t-ph]').forEach(function (el) { el.placeholder = t(el.getAttribute('data-t-ph')); });
  var title = document.querySelector('title[data-t]');
  if (title) document.title = t(title.getAttribute('data-t'));
}
