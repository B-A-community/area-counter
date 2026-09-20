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
    # этажа лежит грань сечения в мировых координатах, то есть ровно там, где
    # резало; двор — дырой в грани. Огибающая и разошедшиеся куски — отдельными
    # подгруппами, чтобы их было видно и легко убрать. Всё одной операцией: Ctrl+Z снимает разом.
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

      # Контур этажа выгружается гранью, а не рёбрами: замкнутые контуры
      # сечения с солида и упрощённая огибающая — одинаково. Двор (контур
      # внутри контура) становится дырой в грани.
      def self.draw_leaf(entities, node)
        faces_from_rings(entities, node.loops.to_a)

        outline = node.envelope.to_a
        unless outline.empty?
          sub = entities.add_group
          sub.name = ENVELOPE_NAME
          faces_from_rings(sub.entities, outline)
        end

        opens = node.opens.to_a.select { |chain| chain.length >= 2 }
        return if opens.empty?
        sub = entities.add_group
        sub.name = OPENS_NAME
        opens.each { |chain| sub.entities.add_edges(chain) }
      end

      # Наружные контуры (чётная вложенность) — грани, вложенные в них
      # (нечётная) — дыры: грань дыры создаём и тут же стираем.
      def self.faces_from_rings(entities, rings)
        rings = rings.map { |ring| clean_ring(ring) }.select { |ring| ring.length >= 3 }
        return if rings.empty?

        depth = rings.map do |ring|
          rings.count { |other| !other.equal?(ring) && Calc.point_inside?(ring[0], other) }
        end

        rings.each_with_index do |ring, i|
          next unless depth[i].even?
          add_face_or_edges(entities, ring)
        end
        rings.each_with_index do |ring, i|
          next if depth[i].even?
          hole = add_face_or_edges(entities, ring)
          hole.erase! if hole
        end
      end

      def self.add_face_or_edges(entities, ring)
        entities.add_face(ring)
      rescue StandardError
        entities.add_edges(ring + [ring.first])
        nil
      end

      # Совпавшие соседние точки ломают add_face — убираем их.
      def self.clean_ring(ring)
        out = []
        ring.each do |point|
          out << point unless out.last && out.last.distance(point) < 1.0e-4
        end
        out.pop if out.length > 1 && out.first.distance(out.last) < 1.0e-4
        out
      end

    end # module Export
  end # module AreaCounter
end # module BACommunity
