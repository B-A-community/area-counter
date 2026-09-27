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
          Panel.notify(AreaCounter.t(:cmd_need_one))
          return
        end
        entity = sel.first

        o = Panel.section_opts
        prompts  = %i[cmd_cut cmd_snap cmd_gap cmd_hidden cmd_holes].map { |k| AreaCounter.t(k) }
        skip     = AreaCounter.t(:opt_skip)
        subtract = AreaCounter.t(:opt_subtract)
        defaults = [o[:cut_mm].to_f, o[:snap_mm].to_f, o[:gap_mm].to_f,
                    o[:ignore_hidden] ? skip : AreaCounter.t(:opt_include),
                    o[:subtract_holes] ? subtract : AreaCounter.t(:opt_keep)]
        lists    = ['', '', '', "#{skip}|#{AreaCounter.t(:opt_include)}", "#{AreaCounter.t(:opt_keep)}|#{subtract}"]
        input = UI.inputbox(prompts, defaults, lists, AreaCounter.t(:cmd_title))
        return unless input

        cut, snap, gap, hidden, holes = input
        if cut.to_f <= 0 || snap.to_f <= 0 || gap.to_f < 0
          Panel.notify(AreaCounter.t(:cmd_bad_values))
          return
        end
        Panel.store_section_opts(cut_mm: cut.to_f, snap_mm: snap.to_f, gap_mm: gap.to_f,
                                 ignore_hidden: hidden == skip,
                                 subtract_holes: holes == subtract)

        Calc.reset_cache
        # В режиме редактирования трансформация выделенного уже мировая (см. Calc.run)
        node = Calc.build(entity, Geom::Transformation.new, 0, 'section', 0, Panel.section_opts)
        r = node.section

        if r.nil? || r[:contour].nil?
          Panel.notify(AreaCounter.t(:cmd_failed, node.reason || AreaCounter.t(:cmd_no_contour)))
          return
        end

        ok, msg = Section::Builder.build([node])
        text = if ok
                 AreaCounter.t(:cmd_done, Report.display_name(node), Report.number(r[:area_m2]), r[:cut_mm].round)
               else
                 msg
               end
        # Итог — в окне плагина: этаж в таблице (оговорки — в его статусе),
        # текст — тостом. UI.messagebox в SketchUp 2024 либо рисует жёлтый
        # треугольник предупреждения, либо раздувается на пол-экрана.
        Panel.show_section_result(node, text)
      end

    end # module Command
  end # module AreaCounter
end # module BACommunity
