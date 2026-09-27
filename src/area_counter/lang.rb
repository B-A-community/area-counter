# Copyright 2026 B&A community
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

# Язык Ruby-части (меню, сообщения, таблицы, имена в модели) — как в RALNCS.
# tools\build_rbz.ps1 -Lang en подменяет строку LANG; окна берут язык
# из html/i18n.js (там та же подмена). Файл без зависимостей от SketchUp:
# его грузит и регистратор, и движок сечения.

module BACommunity
  module AreaCounter
    LANG = 'ru'

    STRINGS = {
      'ru' => {
        ext_description: 'Площади этажей, корпусов и комплексов по верхней грани или по сечению, ' \
                         'таблица в буфер для Google Таблиц / Excel, грани сечений в модели.',
        decimal:         ',',

        # меню и панель инструментов
        menu_count:      'Посчитать площадь',
        tip_count:       'Посчитать площадь выделенного',
        st_count:        'Считает этажи внутри выделенного и открывает окно с итогами',
        menu_panel:      'Окно с таблицей',
        tip_panel:       'Окно с таблицей и итогами',
        st_panel:        'Открывает окно area counter: таблица по этажам, итоги, настройки способа',
        menu_highlight:  'Подсветить посчитанное',
        tip_highlight:   'Подсветить посчитанное',
        st_highlight:    'Обводит во вьюпорте этажи, попавшие в расчёт; проблемные — другим цветом',
        menu_copy:       'Копировать таблицу',
        tip_copy:        'Копировать таблицу в буфер',
        st_copy:         'Кладёт таблицу в буфер обмена — вставляется в Google Таблицы и Excel как есть',
        menu_section:    'Сечение этажа…',
        tip_section:     'Сечение этажа',
        st_section:      'Выделенный этаж: одна плоская грань по внешнему контуру сечения и её площадь',
        menu_volume:     'Объём выделенного',
        tip_volume:      'Объём выделенного (в разработке)',
        st_volume:       'Суммарный объём выделенных солидов — инструмент в разработке',
        menu_about:      'О плагине…',
        title_about:     'О плагине area counter',
        stub:            '«%s» — инструмент ещё не реализован, пункт зарезервирован.',

        # расчёт
        st_counting:     'area counter: считаю…',
        st_progress:     'area counter: обработано этажей %d',
        no_faces:        'внутри нет граней',
        no_horizontal:   'нет горизонтальных граней',
        zero_top:        'верхняя грань нулевой площади',
        st_highlight_on: 'Подсветка area counter. Esc — выйти.',

        # окно
        nothing_selected: 'Ничего не выделено. Выделите корпус, комплекс или этажи.',
        hl_count_first:   'Сначала посчитайте — подсвечивать пока нечего.',
        hl_on:            'Подсветка включена. Esc во вьюпорте — выключить.',
        exp_count_first:  'Сначала посчитайте сечением — выгружать пока нечего.',
        exp_need_section: 'Контуры есть только у сечения: переключите способ и посчитайте заново.',

        # таблицы
        no_name:         'Без имени',
        levels:          %w[Этаж Корпус Комплекс],
        plurals:         %w[Этажи Корпуса Комплексы],
        level_n:         'Уровень %d',
        gen:             %w[этажа корпуса комплекса],       # площадь чего
        gen_n:           'уровня %d',
        loc:             %w[этаже корпусе комплексе],       # этажей в чём
        loc_n:           'уровне %d',
        col_area:        'Площадь %s, м²',
        col_floors:      'Этажей в %s',
        col_blocks:      'Корпусов в %s',

        # команда «Сечение этажа…»
        cmd_title:       'Сечение этажа',
        cmd_need_one:    'Сечение этажа: выделите ровно одну группу или компонент — этаж, и запустите снова.',
        cmd_cut:         'Высота реза от низа этажа, мм',
        cmd_snap:        'Допуск сварки точек, мм',
        cmd_gap:         'Закрывать зазоры до, мм',
        cmd_hidden:      'Скрытое и выключенные теги',
        cmd_holes:       'Внутренние дворы',
        opt_skip:        'пропускать',
        opt_include:     'учитывать',
        opt_keep:        'не вычитать',
        opt_subtract:    'вычитать',
        cmd_bad_values:  'Сечение этажа: высота и допуск сварки должны быть больше нуля, зазор — не меньше нуля.',
        cmd_failed:      'Сечение не построено: %s.',
        cmd_no_contour:  'контур не найден',
        cmd_done:        'Сечение «%s»: %s м² на высоте %d мм. Кликните по грани — площадь покажет ' \
                         'Entity Info. Отмена — Ctrl+Z.',

        # сечения в модели
        tag:             'AC_Сечения',
        root_name:       'area counter: сечения',
        op_section:      'Сечение этажа',
        floor_group:     '%s — сечение %d мм, %s м²',
        exp_nothing:     'Нечего выгружать: посчитайте способом «Сечение».',
        exp_done:        'Создано сечений: %d%s.',
        exp_replaced:    ', прежних заменено: %d',
        exp_undo:        ' Отмена — Ctrl+Z.',
        exp_failed:      'Не удалось создать сечение: %s',
        face_failed:     '«%s»: грань не построилась (вырожденный контур), оставлены рёбра.',
        face_mismatch:   '«%s»: площадь грани %s м² расходится с расчётом %s м².',

        # оговорки движка сечения
        w_ring_broken:   'кольцо разорвано: ни одна высота не прошла проверку',
        w_cut_other:     'высота реза %d мм вместо %d',
        w_cut_shifted:   'рез сдвинут с горизонтальной грани на %d мм',
        w_empty:         'на отметке пусто',
        w_not_closed:    'контур не замкнулся',
        w_fragments:     'найдено отдельных фрагментов: %d (%s м², в площадь этажа не входят)',
        w_self_cross:    'контур самопересекается'
      },

      'en' => {
        ext_description: 'Floor, building and complex areas by top face or by section, a table for ' \
                         'Google Sheets / Excel via the clipboard, section faces in the model.',
        decimal:         '.',

        menu_count:      'Calculate area',
        tip_count:       'Calculate the area of the selection',
        st_count:        'Calculates the floors inside the selection and opens the results window',
        menu_panel:      'Results window',
        tip_panel:       'Window with the table and totals',
        st_panel:        'Opens the area counter window: table by floors, totals, method settings',
        menu_highlight:  'Highlight results',
        tip_highlight:   'Highlight results',
        st_highlight:    'Outlines the calculated floors in the viewport; problem floors in another color',
        menu_copy:       'Copy table',
        tip_copy:        'Copy the table to the clipboard',
        st_copy:         'Puts the table on the clipboard — pastes into Google Sheets and Excel as is',
        menu_section:    'Floor section…',
        tip_section:     'Floor section',
        st_section:      'Selected floor: one flat face along the outer section contour, and its area',
        menu_volume:     'Volume of selection',
        tip_volume:      'Volume of selection (in development)',
        st_volume:       'Total volume of the selected solids — tool in development',
        menu_about:      'About…',
        title_about:     'About area counter',
        stub:            '“%s” is not implemented yet — the menu item is reserved.',

        st_counting:     'area counter: calculating…',
        st_progress:     'area counter: floors processed %d',
        no_faces:        'no faces inside',
        no_horizontal:   'no horizontal faces',
        zero_top:        'top face has zero area',
        st_highlight_on: 'area counter highlight. Esc to exit.',

        nothing_selected: 'Nothing is selected. Select a building, a complex or the floors.',
        hl_count_first:   'Calculate first — nothing to highlight yet.',
        hl_on:            'Highlight is on. Press Esc in the viewport to turn it off.',
        exp_count_first:  'Calculate by section first — nothing to output yet.',
        exp_need_section: 'Only sections have contours: switch the method and calculate again.',

        no_name:         'Unnamed',
        levels:          %w[Floor Building Complex],
        plurals:         %w[Floors Buildings Complexes],
        level_n:         'Level %d',
        gen:             %w[Floor Building Complex],
        gen_n:           'Level %d',
        loc:             %w[floor building complex],
        loc_n:           'level %d',
        col_area:        '%s area, m²',
        col_floors:      'Floors in %s',
        col_blocks:      'Buildings in %s',

        cmd_title:       'Floor section',
        cmd_need_one:    'Floor section: select exactly one group or component — the floor — and run again.',
        cmd_cut:         'Cut height above floor bottom, mm',
        cmd_snap:        'Point weld tolerance, mm',
        cmd_gap:         'Close gaps up to, mm',
        cmd_hidden:      'Hidden objects and tags turned off',
        cmd_holes:       'Inner courtyards',
        opt_skip:        'skip',
        opt_include:     'include',
        opt_keep:        'keep',
        opt_subtract:    'subtract',
        cmd_bad_values:  'Floor section: height and weld tolerance must be greater than zero, gap must not be negative.',
        cmd_failed:      'Section not built: %s.',
        cmd_no_contour:  'contour not found',
        cmd_done:        'Section “%s”: %s m² at %d mm. Click the face — Entity Info shows the area. ' \
                         'Undo — Ctrl+Z.',

        tag:             'AC_Sections',
        root_name:       'area counter: sections',
        op_section:      'Floor section',
        floor_group:     '%s — section %d mm, %s m²',
        exp_nothing:     'Nothing to output: calculate with the “Section” method.',
        exp_done:        'Sections created: %d%s.',
        exp_replaced:    ', previous ones replaced: %d',
        exp_undo:        ' Undo — Ctrl+Z.',
        exp_failed:      'Could not create the section: %s',
        face_failed:     '“%s”: the face could not be built (degenerate contour), edges were left.',
        face_mismatch:   '“%s”: face area %s m² differs from the calculated %s m².',

        w_ring_broken:   'ring is broken: no height passed the check',
        w_cut_other:     'cut height %d mm instead of %d',
        w_cut_shifted:   'cut moved off a horizontal face by %d mm',
        w_empty:         'nothing at this height',
        w_not_closed:    'contour did not close',
        w_fragments:     'separate fragments found: %d (%s m², not included in the floor area)',
        w_self_cross:    'contour intersects itself'
      }
    }.freeze

    def self.t(key, *args)
      table = STRINGS[LANG] || STRINGS['ru']
      s = table.key?(key) ? table[key] : STRINGS['ru'].fetch(key, key.to_s)
      args.empty? ? s : format(s, *args)
    end

    # Число для людей: два знака, разделитель по языку сборки
    # (русские таблицы ждут запятую, английские — точку).
    def self.decimal(value, digits = 2)
      format("%.#{digits}f", value.to_f).tr('.', t(:decimal))
    end
  end
end
