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

    # :action — метод модуля Panel; :stub — инструмент ещё не реализован.
    TOOLBAR_BUTTONS = [
      {
        icon:    'area_top',
        action:  :count_now,
        title:   'Посчитать площадь',
        tooltip: 'Посчитать площадь выделенного',
        status:  'Считает этажи внутри выделенного и открывает окно с итогами'
      },
      {
        icon:    'schedule',
        action:  :show,
        title:   'Окно с таблицей',
        tooltip: 'Окно с таблицей и итогами',
        status:  'Открывает окно area counter: таблица по этажам, итоги, настройки способа'
      },
      {
        icon:    'lengths',
        action:  :highlight_now,
        title:   'Подсветить посчитанное',
        tooltip: 'Подсветить посчитанное',
        status:  'Обводит во вьюпорте этажи, попавшие в расчёт; проблемные — другим цветом'
      },
      {
        icon:    'export',
        action:  :copy_now,
        title:   'Копировать таблицу',
        tooltip: 'Копировать таблицу в буфер',
        status:  'Кладёт таблицу в буфер обмена — вставляется в Google Sheets и Excel как есть'
      },
      {
        icon:    'volume',
        action:  :stub,
        title:   'Объём выделенного',
        tooltip: 'Объём выделенного (в разработке)',
        status:  'Суммарный объём выделенных солидов — инструмент в разработке'
      }
    ].freeze

    # Пара путей [большая иконка, маленькая иконка].
    # SVG понимает только Windows-версия SketchUp (2016+), macOS вместо него
    # требует PDF — поэтому там откатываемся на PNG.
    def self.icon_paths(name)
      svg = File.join(ICONS_DIR, "#{name}.svg")
      if Sketchup.platform == :platform_win && File.exist?(svg)
        [svg, svg]
      else
        [File.join(ICONS_DIR, "#{name}_24.png"), File.join(ICONS_DIR, "#{name}_16.png")]
      end
    end

    def self.not_implemented(title)
      UI.messagebox("«#{title}»\n\nИнструмент ещё не реализован — кнопка зарезервирована.",
                    MB_MULTILINE)
    end

    def self.run_button(spec)
      if spec[:action] == :stub
        not_implemented(spec[:title])
      else
        Panel.public_send(spec[:action])
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

      TOOLBAR_BUTTONS.each_with_index do |spec, index|
        # Отделяем счёт от того, что делают с результатом
        toolbar.add_separator if index == 1
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
