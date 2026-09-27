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

module BACommunity
  module AreaCounter

    # Сценарий ТЗ «чистое сечение этажа»: выделена ровно одна группа-этаж →
    # параметры → в модели одна плоская грань по внешнему контуру, площадь в м².
    # Параметры общие с окном плагина и запоминаются.
    module Command

      def self.floor_section
        model = Sketchup.active_model
        sel   = model.selection.to_a
        unless sel.length == 1 && Calc.group_like?(sel.first)
          UI.messagebox('Выделите ровно одну группу или компонент — этаж, и запустите снова.',
                        MB_MULTILINE)
          return
        end
        entity = sel.first

        o = Panel.section_opts
        prompts  = ['Высота реза от низа этажа, мм', 'Допуск сварки точек, мм',
                    'Закрывать зазоры до, мм', 'Скрытое и выключенные теги', 'Внутренние дворы']
        defaults = [o[:cut_mm].to_f, o[:snap_mm].to_f, o[:gap_mm].to_f,
                    o[:ignore_hidden] ? 'пропускать' : 'учитывать',
                    o[:subtract_holes] ? 'вычитать' : 'не вычитать']
        lists    = ['', '', '', 'пропускать|учитывать', 'не вычитать|вычитать']
        input = UI.inputbox(prompts, defaults, lists, 'Сечение этажа')
        return unless input

        cut, snap, gap, hidden, holes = input
        if cut.to_f <= 0 || snap.to_f <= 0 || gap.to_f < 0
          UI.messagebox('Высота и допуск сварки должны быть больше нуля, зазор — не меньше нуля.', MB_MULTILINE)
          return
        end
        Panel.store_section_opts(cut_mm: cut.to_f, snap_mm: snap.to_f, gap_mm: gap.to_f,
                                 ignore_hidden: hidden == 'пропускать',
                                 subtract_holes: holes == 'вычитать')

        Calc.reset_cache
        # В режиме редактирования трансформация выделенного уже мировая (см. Calc.run)
        node = Calc.build(entity, Geom::Transformation.new, 0, 'section', 0, Panel.section_opts)
        r = node.section

        if r.nil? || r[:contour].nil?
          UI.messagebox("Сечение не построено: #{node.reason || 'контур не найден'}.", MB_MULTILINE)
          return
        end

        ok, msg = Section::Builder.build([node])
        lines = []
        lines << format('Площадь этажа: %s м²', Report.number(r[:area_m2]))
        lines << format('Высота реза: %d мм от низа этажа', r[:cut_mm].round)
        lines << "Внимание: #{r[:reason]}" if r[:reason]
        lines << ''
        lines << msg
        lines << 'Кликните по грани — площадь покажет Entity Info.' if ok
        UI.messagebox(lines.join("\n"), MB_MULTILINE)
      end

    end # module Command
  end # module AreaCounter
end # module BACommunity
