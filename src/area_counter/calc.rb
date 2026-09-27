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

    # Обход дерева от якоря и измерение площади.
    #
    # Якорь — то, что выделено. Этажи лежат на заданной глубине ПОД якорем,
    # и каждый считается целиком, со всем своим содержимым на любой вложенности.
    # Спускаться до самого низа нельзя: там уже не этажи, а витражи и панели.
    #
    # Способов два: верхняя грань (здесь) и сечение (модуль Section — по ТЗ
    # «чистое горизонтальное сечение этажа»).
    module Calc

      M2_PER_IN2 = 0.00064516   # 1 кв. дюйм в кв. метрах
      Z_TOL      = 1.0.mm       # допуск «одна и та же отметка»

      # loops   — контуры сечения (внешний, фрагменты, дворы), opens — снятые
      #           «усы», где контур не сошёлся; всё в мировых координатах для подсветки;
      # section — полный результат Section::Engine, из него строится грань в модели.
      Node = Struct.new(:entity, :name, :children, :area, :status, :reason,
                        :bbox, :zmin, :loops, :opens, :section)

      def self.group_like?(entity)
        entity.is_a?(Sketchup::Group) || entity.is_a?(Sketchup::ComponentInstance)
      end

      def self.inner_entities(entity)
        entity.is_a?(Sketchup::Group) ? entity.entities : entity.definition.entities
      end

      # Видимость слоя спрашиваем один раз на слой: на моделях с сотнями тысяч
      # рёбер этот вопрос сам по себе съедал заметную часть времени.
      def self.reset_cache
        @layer_cache = {}
      end

      def self.layer_visible?(layer)
        return true if layer.nil?
        @layer_cache ||= {}
        key = layer.entityID
        cached = @layer_cache[key]
        return cached unless cached.nil?
        @layer_cache[key] = layer.visible?
      end

      def self.shown?(entity)
        return false if entity.hidden?
        layer_visible?(entity.layer)
      end

      def self.name_of(entity)
        name = entity.name.to_s.strip
        return name unless name.empty?
        # У групп имя по умолчанию пустое: «Группа» рисует Outliner, а не модель.
        # У компонентов остаётся имя определения вида «Компонент#1».
        if entity.is_a?(Sketchup::ComponentInstance)
          defn = entity.definition.name.to_s.strip
          return defn unless defn.empty?
        end
        ''
      end

      # Свои результаты (сечения на теге AC_Сечения) этажами не считаются
      def self.child_groups(entity)
        inner_entities(entity).select do |e|
          group_like?(e) && shown?(e) && !Section::Traversal.own_result?(e)
        end
      end

      # --- обход -------------------------------------------------------------

      # depth — сколько уровней вниз от якоря лежат этажи.
      # 0 — выделены сами этажи, 1 — выделен корпус, 2 — комплекс.
      # offset — отметка реза в дюймах (для совместимости); точные параметры
      # сечения — в opts (см. Section::Engine::DEFAULTS).
      def self.build(entity, parent_tr, depth, method_key, offset, opts = {})
        opts = { cut_mm: offset.to_f * 25.4 }.merge(opts || {})
        tr = parent_tr * entity.transformation

        return leaf(entity, tr, method_key, opts) if depth <= 0

        kids = child_groups(entity)
        # Глубже, чем есть, не лезем: якорь просто оказывается этажом сам.
        return leaf(entity, tr, method_key, opts) if kids.empty?

        children = kids.map { |kid| build(kid, tr, depth - 1, method_key, offset, opts) }
        branch(entity, children)
      end

      def self.branch(entity, children)
        area  = children.inject(0.0) { |sum, node| sum + node.area.to_f }
        boxes = children.map(&:bbox).compact
        bbox  = boxes.empty? ? nil : union_bbox(boxes)
        zmins = children.map(&:zmin).compact
        Node.new(entity, name_of(entity), children, area, :ok, nil, bbox, zmins.min, [], [], nil)
      end

      def self.leaf(entity, tr, method_key, opts)
        @counter = (@counter || 0) + 1
        Sketchup.status_text = AreaCounter.t(:st_progress, @counter) if (@counter % 25).zero?

        return section_leaf(entity, tr, opts) if method_key.to_s == 'section'

        faces = collect_faces(inner_entities(entity), tr)
        if faces.empty?
          return Node.new(entity, name_of(entity), [], 0.0, :problem,
                          AreaCounter.t(:no_faces), nil, nil, [], [], nil)
        end

        box, horiz = scan(faces)
        area, status, reason = top_area(horiz)
        Node.new(entity, name_of(entity), [], area, status, reason,
                 [box.min, box.max], box.min.z, [], [], nil)
      end

      def self.section_leaf(entity, tr, opts)
        r = Section::Engine.section(entity, tr, opts)
        b = r[:bbox]
        bbox = b ? [Geom::Point3d.new(b[0], b[1], b[2]), Geom::Point3d.new(b[3], b[4], b[5])] : nil
        z = r[:height]
        to3d = ->(ring) { ring.map { |(x, y)| Geom::Point3d.new(x, y, z) } }

        loops = []
        if r[:contour]
          loops << to3d.call(r[:contour])
          r[:fragments].each { |ring| loops << to3d.call(ring) }
          r[:holes].each { |ring| loops << to3d.call(ring) }
        end
        opens = r[:whiskers].map do |(x1, y1, x2, y2)|
          [Geom::Point3d.new(x1, y1, z), Geom::Point3d.new(x2, y2, z)]
        end

        Node.new(entity, name_of(entity), [], r[:area_m2], r[:status], r[:reason],
                 bbox, bbox && bbox[0].z, loops, opens, r)
      end

      # Собирает грани вместе с накопленной трансформацией на всю глубину.
      # Класс сверяем напрямую: на рёбрах, которых в модели больше всего,
      # это выходит заметно дешевле цепочки is_a?.
      def self.collect_faces(entities, tr, acc = [])
        entities.each do |entity|
          klass = entity.class
          if klass == Sketchup::Face
            acc << [entity, tr] if shown?(entity)
          elsif klass == Sketchup::Group
            collect_faces(entity.entities, tr * entity.transformation, acc) if shown?(entity) && !Section::Traversal.own_result?(entity)
          elsif klass == Sketchup::ComponentInstance
            collect_faces(entity.definition.entities, tr * entity.transformation, acc) if shown?(entity) && !Section::Traversal.own_result?(entity)
          end
        end
        acc
      end

      # Один проход по вершинам: габарит и горизонтальные грани.
      def self.scan(faces)
        box   = Geom::BoundingBox.new
        horiz = []
        faces.each do |(face, tr)|
          low  = nil
          high = nil
          face.outer_loop.vertices.each do |vertex|
            point = vertex.position.transform(tr)
            box.add(point)
            z = point.z
            low  = z if low.nil?  || z < low
            high = z if high.nil? || z > high
          end
          next if low.nil?
          horiz << [face, tr, (low + high) / 2.0] if (high - low) <= Z_TOL
        end
        [box, horiz]
      end

      def self.union_bbox(boxes)
        box = Geom::BoundingBox.new
        boxes.each { |(low, high)| box.add(low); box.add(high) }
        [box.min, box.max]
      end

      # --- способ 1: верхние горизонтальные грани ----------------------------
      #
      # Работаем в мировых координатах, поэтому повёрнутые оси группы не мешают,
      # и берём ВСЕ грани верхней отметки, а не одну: уступ наверху больше
      # не съедает часть площади.
      def self.top_area(horiz)
        return [0.0, :problem, AreaCounter.t(:no_horizontal)] if horiz.empty?

        top    = horiz.map { |item| item[2] }.max
        on_top = horiz.select { |item| (top - item[2]).abs <= Z_TOL }
        in2    = on_top.inject(0.0) { |sum, item| sum + item[0].area(item[1]) }
        area   = in2 * M2_PER_IN2

        return [0.0, :problem, AreaCounter.t(:zero_top)] if area <= 0.0
        [area, :ok, nil]
      end

      # --- точка входа -------------------------------------------------------

      # Выделение может быть внутри открытой на редактирование группы. ТЗ
      # просит учесть model.edit_transform, но SketchUp в этом режиме САМ отдаёт
      # трансформации открытого контекста в мировых координатах — умножение на
      # edit_transform их удваивает (поймано тестом ТЗ-9). Поэтому от единичной.
      def self.run(method_key, offset_mm, depth, opts = {})
        model   = Sketchup.active_model
        anchors = model.selection.to_a.select { |e| group_like?(e) && !Section::Traversal.own_result?(e) }
        return nil if anchors.empty?

        reset_cache
        @counter = 0
        Sketchup.status_text = AreaCounter.t(:st_counting)

        offset = offset_mm.to_f.mm
        origin = Geom::Transformation.new
        roots  = anchors.map { |a| build(a, origin, depth.to_i, method_key, offset, opts) }
        sort_tree(roots)

        Sketchup.status_text = ''
        roots
      end

      # Сколько уровней групп лежит под якорем — подсказка для выбора глубины.
      def self.available_depth(entity, limit = 4)
        return 0 if limit <= 0
        kids = child_groups(entity)
        return 0 if kids.empty?
        1 + kids.map { |kid| available_depth(kid, limit - 1) }.max
      end

      def self.sort_tree(nodes)
        nodes.sort_by! { |n| n.zmin.nil? ? Float::INFINITY : n.zmin.to_f }
        nodes.each { |n| sort_tree(n.children) unless n.children.empty? }
      end

      def self.leaves(nodes, acc = [])
        nodes.each do |node|
          if node.children.empty?
            acc << node
          else
            leaves(node.children, acc)
          end
        end
        acc
      end

    end # module Calc
  end # module AreaCounter
end # module BACommunity
