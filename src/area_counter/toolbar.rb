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
# Логика расчётов живёт в main.rb — здесь только UI.
module BACommunity
  module AreaCounter

    TOOLBAR_NAME = 'area counter'.freeze
    MENU_NAME    = 'area counter'.freeze
    ICONS_DIR    = File.join(File.dirname(__FILE__), 'icons').freeze

    # Кнопки панели слева направо.
    # :action — имя метода модуля; :stub означает «инструмент ещё не реализован».
    TOOLBAR_BUTTONS = [
      {
        icon:    'area_top',
        action:  :my_method,
        title:   'Площадь верхних граней',
        tooltip: 'Площадь верхних граней',
        status:  'Суммирует площадь верхних горизонтальных граней выделенных групп и компонентов'
      },
      {
        icon:    'volume',
        action:  :stub,
        title:   'Объём выделенного',
        tooltip: 'Объём выделенного (в разработке)',
        status:  'Суммарный объём выделенных солидов — инструмент в разработке'
      },
      {
        icon:    'lengths',
        action:  :stub,
        title:   'Длины и периметр',
        tooltip: 'Длины и периметр (в разработке)',
        status:  'Суммарная длина рёбер и периметр контуров — инструмент в разработке'
      },
      {
        icon:    'schedule',
        action:  :stub,
        title:   'Спецификация',
        tooltip: 'Спецификация (в разработке)',
        status:  'Ведомость элементов с количеством и размерами — инструмент в разработке'
      },
      {
        icon:    'export',
        action:  :stub,
        title:   'Экспорт расчёта',
        tooltip: 'Экспорт расчёта (в разработке)',
        status:  'Выгрузка результатов расчёта в CSV — инструмент в разработке'
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
      UI.messagebox("«#{title}»\n\nИнструмент ещё не реализован — кнопка зарезервирована.")
    end

    def self.run_button(spec)
      if spec[:action] == :stub
        not_implemented(spec[:title])
      else
        send(spec[:action])
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
        # Отделяем рабочий инструмент от заготовок
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
