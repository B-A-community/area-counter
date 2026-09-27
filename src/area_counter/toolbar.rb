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

require 'sketchup.rb'

# Оформление плагина: панель инструментов и меню.
# Расчёт живёт в calc.rb, окно — в panel.rb.
module BACommunity
  module AreaCounter

    TOOLBAR_NAME = 'area counter'.freeze
    MENU_NAME    = 'area counter'.freeze
    ICONS_DIR    = File.join(File.dirname(__FILE__), 'icons').freeze

    # :action — метод модуля Panel (или Command для :floor_section);
    # :stub — инструмент ещё не реализован. На панели инструментов — только
    # кнопки с toolbar: true, в меню — все.
    TOOLBAR_BUTTONS = [
      {
        icon:    'area_top',
        action:  :count_now,
        toolbar: true,
        title:   'Посчитать площадь',
        tooltip: 'Посчитать площадь выделенного',
        status:  'Считает этажи внутри выделенного и открывает окно с итогами'
      },
      {
        icon:    'area_top',
        action:  :show,
        title:   'Окно с таблицей',
        tooltip: 'Окно с таблицей и итогами',
        status:  'Открывает окно area counter: таблица по этажам, итоги, настройки способа'
      },
      {
        icon:    'area_top',
        action:  :highlight_now,
        title:   'Подсветить посчитанное',
        tooltip: 'Подсветить посчитанное',
        status:  'Обводит во вьюпорте этажи, попавшие в расчёт; проблемные — другим цветом'
      },
      {
        icon:    'area_top',
        action:  :copy_now,
        title:   'Копировать таблицу',
        tooltip: 'Копировать таблицу в буфер',
        status:  'Кладёт таблицу в буфер обмена — вставляется в Google Sheets и Excel как есть'
      },
      {
        icon:    'area_top',
        action:  :floor_section,
        title:   'Сечение этажа…',
        tooltip: 'Сечение этажа',
        status:  'Выделенный этаж: одна плоская грань по внешнему контуру сечения и её площадь'
      },
      {
        icon:    'area_top',
        action:  :stub,
        title:   'Объём выделенного',
        tooltip: 'Объём выделенного (в разработке)',
        status:  'Суммарный объём выделенных солидов — инструмент в разработке'
      }
    ].freeze

    # По дизайн-коду B&A один и тот же плоский SVG идёт и в small_icon,
    # и в large_icon. Целевая платформа — SketchUp 2024 на Windows; macOS
    # SVG не понимает, ему нужен PDF, которого у нас нет.
    def self.icon_paths(name)
      svg = File.join(ICONS_DIR, "#{name}.svg")
      [svg, svg]
    end

    def self.not_implemented(title)
      Panel.notify("«#{title}» — инструмент ещё не реализован, пункт зарезервирован.")
    end

    def self.run_button(spec)
      case spec[:action]
      when :stub          then not_implemented(spec[:title])
      when :floor_section then Command.floor_section
      else Panel.public_send(spec[:action])
      end
    end

    def self.build_command(spec)
      cmd = UI::Command.new(spec[:title]) { run_button(spec) }

      large_icon, small_icon = icon_paths(spec[:icon])
      # Иконку ставим только если файл на месте: иначе SketchUp ругается,
      # а кнопка всё равно останется работоспособной с подписью.
      cmd.large_icon = large_icon if File.exist?(large_icon)
      cmd.small_icon = small_icon if File.exist?(small_icon)

      cmd.tooltip         = spec[:tooltip]
      cmd.status_bar_text = spec[:status]
      cmd
    end

    def self.create_toolbar
      toolbar = UI::Toolbar.new(TOOLBAR_NAME)

      TOOLBAR_BUTTONS.select { |spec| spec[:toolbar] }.each do |spec|
        toolbar.add_item(build_command(spec))
      end

      # Первый запуск — показываем панель, дальше уважаем выбор пользователя
      if toolbar.get_last_state == TB_NEVER_SHOWN
        toolbar.show
      else
        toolbar.restore
      end

      toolbar
    end

    def self.create_menu
      menu = UI.menu('Plugins').add_submenu(MENU_NAME)
      TOOLBAR_BUTTONS.each do |spec|
        menu.add_item(spec[:title]) { run_button(spec) }
      end
      menu
    end

  end # module AreaCounter
end # module BACommunity
