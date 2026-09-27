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
    module Section

      # Шаг 8 ТЗ: результат в модели.
      #
      # В корне модели — группа «area counter: сечения» на теге AC_Сечения,
      # внутри та же иерархия, что в расчёте (комплекс → корпус → этаж).
      # В группе этажа — ОДНА плоская грань по внешнему контуру на высоте реза;
      # по клику Entity Info показывает её площадь. Отдельные фрагменты —
      # отдельными гранями рядом. Исходная геометрия этажа не трогается.
      # Всё одной операцией: Ctrl+Z снимает целиком.
      module Builder

        DICT = Traversal::DICT
        TAG  = Traversal::TAG

        # roots — дерево из Calc (листья несут node.section — результат Engine).
        # Возвращает [успех, сообщение].
        def self.build(roots)
          model  = Sketchup.active_model
          leaves = Calc.leaves(roots).select { |leaf| leaf.section && leaf.section[:contour] }
          return [false, 'Нечего выгружать: посчитайте способом «Сечение».'] if leaves.empty?

          notes = []
          model.start_operation('Сечение этажа', true)
          begin
            tag = model.layers[TAG] || model.layers.add(TAG)
            removed = remove_previous(model, leaves.map { |leaf| pid_of(leaf.entity) }.compact)

            root = model.entities.add_group
            root.name  = 'area counter: сечения'
            root.layer = tag
            root.set_attribute(DICT, 'role', 'container')
            roots.each { |node| build_node(root.entities, node, tag, notes) }
            erase_if_empty(root)

            model.commit_operation
            msg = format('Создано сечений: %d%s.', leaves.length,
                         removed > 0 ? ", прежних заменено: #{removed}" : '')
            msg += ' ' + notes.join(' ') unless notes.empty?
            [true, msg + ' Отмена — Ctrl+Z.']
          rescue StandardError => e
            model.abort_operation
            [false, "Не удалось создать сечение: #{e.message}"]
          end
        end

        def self.pid_of(entity)
          return nil if entity.nil? || entity.deleted?
          entity.respond_to?(:persistent_id) ? entity.persistent_id : entity.entityID
        end

        def self.build_node(entities, node, tag, notes)
          if node.children.empty?
            build_floor(entities, node, tag, notes)
          else
            group = entities.add_group
            group.name = Report.display_name(node)
            group.set_attribute(DICT, 'role', 'container')
            node.children.each { |child| build_node(group.entities, child, tag, notes) }
            erase_if_empty(group)
          end
        end

        def self.build_floor(entities, node, tag, notes)
          r = node.section
          return if r.nil? || r[:contour].nil?
          z = r[:height]
          name = Report.display_name(node)

          group = entities.add_group
          group.layer = tag
          group.name  = format('%s — сечение %d мм, %s м²', name, r[:cut_mm].round, Report.number(r[:area_m2]))

          face = add_face(group.entities, r[:contour], z)
          if face.nil?
            notes << "«#{name}»: грань не построилась (вырожденный контур), оставлены рёбра."
          end
          r[:holes].each do |hole|
            hole_face = add_face(group.entities, hole, z)
            hole_face.erase! if hole_face
          end
          r[:fragments].each { |ring| add_face(group.entities, ring, z) }

          # Контрольная сверка: формула шнурков против площади грани
          if face && !face.deleted?
            expected = r[:area_m2]
            got = face.area * Engine::M2_PER_IN2
            if expected > 0 && ((got - expected) / expected).abs > 1.0e-4
              notes << format('«%s»: площадь грани %.3f м² расходится с расчётом %.3f м².', name, got, expected)
            end
          end

          group.set_attribute(DICT, 'role', 'section')
          group.set_attribute(DICT, 'floor_pid', pid_of(node.entity))
          group.set_attribute(DICT, 'cut_mm', r[:cut_mm].round(1))
          group.set_attribute(DICT, 'area_m2', r[:area_m2].round(4))
          group.set_attribute(DICT, 'date', Time.now.strftime('%Y-%m-%d %H:%M'))
          group
        end

        def self.add_face(entities, ring, z)
          points = ring.map { |(x, y)| Geom::Point3d.new(x, y, z) }
          face = begin
            entities.add_face(points)
          rescue StandardError
            nil
          end
          if face.nil?
            begin
              entities.add_edges(points + [points.first])
            rescue StandardError
              nil
            end
            return nil
          end
          face.reverse! if face.normal.z < 0
          face
        end

        # При повторном запуске прежнее сечение того же этажа удаляется —
        # ищем по floor_pid, заходим только в свои группы.
        def self.remove_previous(model, pids)
          return 0 if pids.empty?
          wanted = {}
          pids.each { |pid| wanted[pid] = true }
          doomed = []
          containers = []
          scan = lambda do |ents|
            ents.grep(Sketchup::Group).each do |g|
              role = g.get_attribute(DICT, 'role')
              next unless role
              if role == 'section'
                doomed << g if wanted[g.get_attribute(DICT, 'floor_pid')]
              else
                containers << g
                scan.call(g.entities)
              end
            end
          end
          scan.call(model.entities)
          doomed.each { |g| g.erase! unless g.deleted? }
          containers.reverse_each { |g| erase_if_empty(g) }
          doomed.length
        end

        def self.erase_if_empty(group)
          return if group.deleted?
          ents = group.entities
          has_content = ents.any? { |e| e.is_a?(Sketchup::Face) || e.is_a?(Sketchup::Group) || e.is_a?(Sketchup::Edge) }
          group.erase! unless has_content
        end

      end # module Builder
    end # module Section
  end # module AreaCounter
end # module BACommunity
