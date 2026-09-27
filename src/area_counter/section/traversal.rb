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

      # Шаг 1 ТЗ: обход иерархии этажа и сбор граней в мировых координатах.
      # Единственный модуль сечения, который знает про API SketchUp на входе.
      module Traversal

        DICT = 'area_counter'.freeze
        TAG  = AreaCounter.t(:tag).freeze
        # Тег обеих языковых сборок: сечения, выгруженные русской версией,
        # английская тоже не считает этажами — и наоборот
        TAGS = AreaCounter::STRINGS.values.map { |s| s[:tag] }.uniq.freeze

        # Возвращает { faces: [{ rings:, normal:, zmin:, zmax: }],
        #              bbox: [minx, miny, minz, maxx, maxy, maxz] или nil,
        #              flats: [z горизонтальных граней] }
        def self.collect(entity, world_tr, ignore_hidden)
          @layer_cache = {}
          acc = { faces: [], flats: [],
                  box: [Float::INFINITY, Float::INFINITY, Float::INFINITY,
                        -Float::INFINITY, -Float::INFINITY, -Float::INFINITY] }
          walk(inner_entities(entity), world_tr, ignore_hidden, acc)
          box = acc[:box]
          { faces: acc[:faces], flats: acc[:flats].sort,
            bbox: box[0].finite? ? box : nil }
        end

        def self.inner_entities(entity)
          entity.is_a?(Sketchup::Group) ? entity.entities : entity.definition.entities
        end

        def self.walk(entities, tr, ignore_hidden, acc)
          det_sign = determinant(tr) < 0 ? -1.0 : 1.0
          entities.each do |e|
            klass = e.class
            if klass == Sketchup::Face
              next if ignore_hidden && !shown?(e)
              add_face(e, tr, det_sign, acc)
            elsif klass == Sketchup::Group || klass == Sketchup::ComponentInstance
              next if own_result?(e)
              next if ignore_hidden && !shown?(e)
              defn = klass == Sketchup::Group ? e.entities : e.definition.entities
              walk(defn, tr * e.transformation, ignore_hidden, acc)
            end
          end
        end

        def self.add_face(face, tr, det_sign, acc)
          rings = []
          zmin = Float::INFINITY
          zmax = -Float::INFINITY
          box  = acc[:box]
          face.loops.each do |lp|
            ring = lp.vertices.map do |v|
              p = v.position.transform(tr)
              x = p.x.to_f
              y = p.y.to_f
              z = p.z.to_f
              zmin = z if z < zmin
              zmax = z if z > zmax
              box[0] = x if x < box[0]
              box[1] = y if y < box[1]
              box[2] = z if z < box[2]
              box[3] = x if x > box[3]
              box[4] = y if y > box[4]
              box[5] = z if z > box[5]
              [x, y, z]
            end
            lp.outer? ? rings.unshift(ring) : rings << ring
          end

          # Нормаль по вершинам (метод Ньюэлла) в мировых координатах. У зеркальной
          # трансформации порядок вершин переворачивается — поправляем знаком.
          nx, ny, nz = newell(rings.first)
          normal = [nx * det_sign, ny * det_sign, nz * det_sign]

          if (zmax - zmin) < 1.0e-6
            acc[:flats] << (zmin + zmax) / 2.0
          else
            acc[:faces] << { rings: rings, normal: normal, zmin: zmin, zmax: zmax }
          end
        end

        def self.newell(ring)
          nx = ny = nz = 0.0
          count = ring.length
          count.times do |i|
            a = ring[i]
            b = ring[(i + 1) % count]
            nx += (a[1] - b[1]) * (a[2] + b[2])
            ny += (a[2] - b[2]) * (a[0] + b[0])
            nz += (a[0] - b[0]) * (a[1] + b[1])
          end
          len = Math.sqrt(nx * nx + ny * ny + nz * nz)
          len < 1.0e-12 ? [0.0, 0.0, 1.0] : [nx / len, ny / len, nz / len]
        end

        def self.determinant(tr)
          m = tr.to_a
          m[0] * (m[5] * m[10] - m[6] * m[9]) -
            m[4] * (m[1] * m[10] - m[2] * m[9]) +
            m[8] * (m[1] * m[6] - m[2] * m[5])
        end

        # Собственные результаты плагина в сечение не попадают никогда
        def self.own_result?(entity)
          return true if entity.attribute_dictionary(DICT)
          layer = entity.layer
          !layer.nil? && TAGS.include?(layer.name)
        end

        def self.shown?(entity)
          return false if entity.hidden?
          layer_visible?(entity.layer)
        end

        # Видимость тега с учётом папок тегов (SketchUp 2021+)
        def self.layer_visible?(layer)
          return true if layer.nil?
          key = layer.entityID
          return @layer_cache[key] if @layer_cache.key?(key)
          visible = layer.visible?
          if visible && layer.respond_to?(:folder)
            folder = layer.folder
            while folder && visible
              visible = folder.visible?
              folder = folder.respond_to?(:folder) ? folder.folder : nil
            end
          end
          @layer_cache[key] = visible
        end

      end # module Traversal
    end # module Section
  end # module AreaCounter
end # module BACommunity
