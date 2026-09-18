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

    # Выгрузка контуров сечения в модель.
    #
    # Создаёт в корне модели группу «area counter: сечение N мм», внутри —
    # та же иерархия, что в дереве расчёта: комплекс → корпус → этаж. В группе
    # этажа лежат рёбра контура в мировых координатах, то есть ровно там, где
    # резало. Разошедшиеся куски и огибающая — отдельными подгруппами, чтобы
    # их было видно и легко убрать. Всё одной операцией: Ctrl+Z снимает разом.
    module Export

      OPENS_NAME    = 'разошлось'.freeze
      ENVELOPE_NAME = 'огибающая'.freeze

      # Возвращает [успех, сообщение для тоста].
      def self.contours(roots, offset_mm)
        model  = Sketchup.active_model
        leaves = Calc.leaves(roots)
        with_contours = leaves.count { |leaf| has_contours?(leaf) }
        if with_contours.zero?
          return [false, 'Контуров нет: считайте способом «Сечение», потом выгружайте.']
        end

        model.start_operation('area counter: контуры сечения', true)
        begin
          root = model.entities.add_group
          root.name = "area counter: сечение #{offset_mm.to_i} мм"
          roots.each { |node| build(root.entities, node) }
          model.commit_operation
        rescue StandardError => e
          model.abort_operation
          return [false, "Не удалось выгрузить: #{e.message}"]
        end

        [true, "Создана группа «#{root.name}»: этажей с контурами #{with_contours}. Отмена — Ctrl+Z."]
      end

      def self.has_contours?(node)
        !(node.loops.to_a.empty? && node.opens.to_a.empty? && node.envelope.to_a.empty?)
      end

      # Пустые группы SketchUp сам убирает при завершении операции,
      # поэтому ветки без контуров не оставят мусора.
      def self.build(entities, node)
        group = entities.add_group
        group.name = Report.display_name(node)
        if node.children.empty?
          draw_leaf(group.entities, node)
        else
          node.children.each { |child| build(group.entities, child) }
        end
        group
      end

      def self.draw_leaf(entities, node)
        node.loops.to_a.each do |ring|
          next if ring.length < 2
          entities.add_edges(ring + [ring.first])
        end

        opens = node.opens.to_a.select { |chain| chain.length >= 2 }
        unless opens.empty?
          sub = entities.add_group
          sub.name = OPENS_NAME
          opens.each { |chain| sub.entities.add_edges(chain) }
        end

        outline = node.envelope.to_a
        return if outline.length < 2

        sub = entities.add_group
        sub.name = ENVELOPE_NAME
        merge_outline(outline).each { |(a, b)| sub.entities.add_edges(a, b) }
      end

      # Огибающая приходит клетками растра — тысячи коротких рёбер. Склеиваем
      # соседние на одной прямой в длинные, чтобы стена была одним ребром.
      def self.merge_outline(outline)
        horizontal = Hash.new { |h, k| h[k] = [] }
        vertical   = Hash.new { |h, k| h[k] = [] }
        tol = 1.0e-3

        outline.each_slice(2) do |(a, b)|
          next if a.nil? || b.nil?
          if (a.y - b.y).abs < tol
            horizontal[(a.y / tol).round] << [[a.x, b.x].min, [a.x, b.x].max, a.y, a.z]
          elsif (a.x - b.x).abs < tol
            vertical[(a.x / tol).round] << [[a.y, b.y].min, [a.y, b.y].max, a.x, a.z]
          end
        end

        merged = []
        horizontal.each_value do |runs|
          merge_runs(runs, tol).each do |(x0, x1, y, z)|
            merged << [Geom::Point3d.new(x0, y, z), Geom::Point3d.new(x1, y, z)]
          end
        end
        vertical.each_value do |runs|
          merge_runs(runs, tol).each do |(y0, y1, x, z)|
            merged << [Geom::Point3d.new(x, y0, z), Geom::Point3d.new(x, y1, z)]
          end
        end
        merged
      end

      def self.merge_runs(runs, tol)
        runs.sort_by! { |run| run[0] }
        out = []
        runs.each do |run|
          last = out.last
          if last && run[0] <= last[1] + tol
            last[1] = run[1] if run[1] > last[1]
          else
            out << run.dup
          end
        end
        out
      end

    end # module Export
  end # module AreaCounter
end # module BACommunity
