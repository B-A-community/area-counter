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
    # Якорь — то, что выделено. Плагин не знает слов «этаж» и «корпус»:
    # он спускается вглубь, пока встречает одни только группы, и считает
    # площадь там, где начинается собственная геометрия. Итоги суммируются
    # снизу вверх, сколько бы уровней ни оказалось.
    module Calc

      M2_PER_IN2 = 0.00064516   # 1 кв. дюйм в кв. метрах
      Z_TOL      = 1.0.mm       # допуск «одна и та же отметка»
      GAP        = 50.0.mm      # разрыв, который считаем одной стеной (В5)
      MIN_LOOP   = 0.01 / M2_PER_IN2  # контуры мельче 0.01 м² — это мусор

      # entity   — сама группа или компонент
      # name     — имя для таблицы
      # children — вложенные узлы, пусто у листа
      # area     — кв. метры; у ветки это сумма детей
      # status   — :ok или :problem
      # reason   — почему :problem, человеческим языком
      # bbox     — [мин, макс] в мировых координатах, для подсветки
      # zmin     — низ, по нему сортируем этажи снизу вверх
      Node = Struct.new(:entity, :name, :children, :area, :status, :reason, :bbox, :zmin)

      def self.group_like?(entity)
        entity.is_a?(Sketchup::Group) || entity.is_a?(Sketchup::ComponentInstance)
      end

      def self.inner_entities(entity)
        entity.is_a?(Sketchup::Group) ? entity.entities : entity.definition.entities
      end

      def self.shown?(entity)
        return false if entity.hidden?
        layer = entity.layer
        layer.nil? || layer.visible?
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

      # --- обход -------------------------------------------------------------

      def self.build(entity, parent_tr, method_key, offset)
        tr    = parent_tr * entity.transformation
        inner = inner_entities(entity)

        own_faces = inner.grep(Sketchup::Face)
        kids      = inner.select { |e| group_like?(e) && shown?(e) }

        # Группа с собственными гранями — это лист, даже если внутри есть
        # ещё группы: «группа элементов = этаж».
        if kids.empty? || !own_faces.empty?
          leaf(entity, tr, method_key, offset)
        else
          children = kids.map { |kid| build(kid, tr, method_key, offset) }
          branch(entity, children)
        end
      end

      def self.branch(entity, children)
        area = children.inject(0.0) { |sum, node| sum + node.area.to_f }
        boxes = children.map(&:bbox).compact
        bbox  = boxes.empty? ? nil : union_bbox(boxes)
        zmins = children.map(&:zmin).compact
        Node.new(entity, name_of(entity), children, area, :ok, nil, bbox, zmins.min)
      end

      def self.leaf(entity, tr, method_key, offset)
        faces = collect_faces(inner_entities(entity), tr)
        bbox  = bbox_of(faces)

        if faces.empty?
          return Node.new(entity, name_of(entity), [], 0.0, :problem,
                          'внутри нет граней', nil, nil)
        end

        area, status, reason =
          if method_key.to_s == 'section'
            section_area(faces, offset)
          else
            top_area(faces)
          end

        Node.new(entity, name_of(entity), [], area, status, reason, bbox, bbox[0].z)
      end

      # Собирает грани вместе с накопленной трансформацией на всю глубину.
      # Именно этого не хватало прежней версии: она смотрела только первый
      # уровень, поэтому этаж с вложенной группой давал ноль.
      def self.collect_faces(entities, tr, acc = [])
        entities.each do |entity|
          next unless entity.respond_to?(:hidden?) && shown?(entity)
          case entity
          when Sketchup::Face
            acc << [entity, tr]
          when Sketchup::Group
            collect_faces(entity.entities, tr * entity.transformation, acc)
          when Sketchup::ComponentInstance
            collect_faces(entity.definition.entities, tr * entity.transformation, acc)
          end
        end
        acc
      end

      # --- габариты ----------------------------------------------------------

      def self.bbox_of(faces)
        box = Geom::BoundingBox.new
        faces.each do |(face, tr)|
          face.outer_loop.vertices.each { |v| box.add(v.position.transform(tr)) }
        end
        [box.min, box.max]
      end

      def self.union_bbox(boxes)
        box = Geom::BoundingBox.new
        boxes.each { |(mn, mx)| box.add(mn); box.add(mx) }
        [box.min, box.max]
      end

      # --- способ 1: верхние горизонтальные грани ----------------------------
      #
      # Работаем в мировых координатах: грань «горизонтальна», если все её
      # вершины на одной отметке. Повёрнутые оси группы больше не мешают.
      # И берём ВСЕ грани верхней отметки, а не одну, — иначе уступ на верху
      # съедал бы часть площади.
      def self.top_area(faces)
        level = []
        faces.each do |(face, tr)|
          zs = face.outer_loop.vertices.map { |v| v.position.transform(tr).z }
          next if zs.max - zs.min > Z_TOL
          level << [face, tr, (zs.max + zs.min) / 2.0]
        end

        return [0.0, :problem, 'нет горизонтальных граней'] if level.empty?

        top   = level.map { |item| item[2] }.max
        onTop = level.select { |item| (top - item[2]).abs <= Z_TOL }
        in2   = onTop.inject(0.0) { |sum, item| sum + item[0].area(item[1]) }
        area  = in2 * M2_PER_IN2

        return [0.0, :problem, 'верхняя грань нулевой площади'] if area <= 0.0
        [area, :ok, nil]
      end

      # --- способ 2: горизонтальное сечение на отметке -----------------------
      #
      # Модель не трогаем вообще: сечение считается аналитически по граням.
      # Отметка отмеряется от низа группы-этажа (В3), внутренние дворы
      # вычитаются вложенностью контуров (В4), разрывы до 50 мм смыкаются (В5).
      def self.section_area(faces, offset)
        zmin = nil
        faces.each do |(face, tr)|
          face.outer_loop.vertices.each do |v|
            z = v.position.transform(tr).z
            zmin = z if zmin.nil? || z < zmin
          end
        end
        return [0.0, :problem, 'внутри нет граней'] if zmin.nil?

        cut  = safe_cut_level(faces, zmin + offset)
        segs = []
        faces.each { |(face, tr)| segs.concat(plane_segments(face, tr, cut)) }

        return [0.0, :problem, 'на отметке пусто'] if segs.empty?

        loops, dangling = chain_loops(segs, GAP)
        return [0.0, :problem, 'контур не замкнулся'] if loops.empty?

        area = loops_area(loops) * M2_PER_IN2
        return [0.0, :problem, 'сечение нулевой площади'] if area <= 0.0
        return [area, :problem, 'контур замкнулся не весь'] if dangling

        [area, :ok, nil]
      end

      # Вершина ровно на секущей плоскости даёт вырожденное пересечение,
      # поэтому отметку слегка сдвигаем, если она попала в вершины.
      def self.safe_cut_level(faces, cut)
        eps = 0.02.mm
        5.times do
          touching = false
          faces.each do |(face, tr)|
            face.outer_loop.vertices.each do |v|
              if (v.position.transform(tr).z - cut).abs < eps
                touching = true
                break
              end
            end
            break if touching
          end
          return cut unless touching
          cut += 0.05.mm
        end
        cut
      end

      # Пересечение одной грани с горизонтальной плоскостью: набор отрезков.
      def self.plane_segments(face, tr, cut)
        outer = face.outer_loop.vertices.map { |v| v.position.transform(tr) }
        rings = face.loops.map { |lp| lp.vertices.map { |v| v.position.transform(tr) } }
        all   = rings.inject([]) { |acc, ring| acc + ring }
        return [] if all.length < 3 || outer.length < 3

        zs = all.map(&:z)
        return [] if zs.max - zs.min <= Z_TOL          # горизонтальная грань
        return [] if cut <= zs.min || cut >= zs.max    # плоскость мимо грани

        # Нормаль считаем по внешнему контуру, а не по face.normal:
        # так не зависим от того, как трансформация повлияла бы на нормаль.
        normal = plane_normal(outer)
        return [] if normal.nil?
        dir = normal.cross(Z_AXIS)
        return [] if dir.length < 1.0e-9
        dir.normalize!

        points = []
        rings.each do |ring|
          count = ring.length
          count.times do |i|
            a = ring[i]
            b = ring[(i + 1) % count]
            da = a.z - cut
            db = b.z - cut
            next if da > 0 && db > 0
            next if da < 0 && db < 0
            next if da == db
            t = da / (da - db)
            next if t < 0.0 || t > 1.0
            points << Geom::Point3d.new(a.x + (b.x - a.x) * t,
                                        a.y + (b.y - a.y) * t,
                                        cut)
          end
        end

        points = dedupe(points, 1.0e-4)
        return [] if points.length < 2

        points.sort_by! { |p| p.x * dir.x + p.y * dir.y }

        segs = []
        index = 0
        while index + 1 < points.length
          a = points[index]
          b = points[index + 1]
          segs << [a, b] if a.distance(b) > 1.0e-6
          index += 2
        end
        segs
      end

      def self.plane_normal(ring)
        origin = ring[0]
        (1...(ring.length - 1)).each do |i|
          v1 = ring[i] - origin
          v2 = ring[i + 1] - origin
          n  = v1.cross(v2)
          return n.normalize if n.length > 1.0e-9
        end
        nil
      end

      def self.dedupe(points, tol)
        kept = []
        points.each do |p|
          kept << p unless kept.any? { |q| q.distance(p) <= tol }
        end
        kept
      end

      # Сшивает отрезки в замкнутые контуры, прощая разрывы до gap.
      # Возвращает [контуры, был_ли_незамкнутый_кусок].
      def self.chain_loops(segs, gap)
        left     = segs.dup
        loops    = []
        dangling = false

        until left.empty?
          first, second = left.shift
          poly = [first, second]

          loop do
            tail    = poly.last
            closing = poly.first.distance(tail)

            best_d = nil
            best_i = nil
            best_flip = false
            left.each_with_index do |(p, q), i|
              d1 = tail.distance(p)
              if best_d.nil? || d1 < best_d
                best_d = d1; best_i = i; best_flip = false
              end
              d2 = tail.distance(q)
              if d2 < best_d
                best_d = d2; best_i = i; best_flip = true
              end
            end

            if poly.length >= 3 && closing <= 1.0e-4
              break
            end
            if best_i.nil? || best_d > gap
              dangling = true if closing > gap || poly.length < 3
              break
            end

            seg = left.delete_at(best_i)
            poly << (best_flip ? seg[0] : seg[1])
          end

          loops << poly if poly.length >= 3 && poly.first.distance(poly.last) <= gap
        end

        [loops, dangling]
      end

      # Площадь набора контуров: вложенный контур вычитается.
      # Двор внутри корпуса уходит в минус, отдельно стоящая башня — в плюс.
      def self.loops_area(loops)
        polys = loops.map { |lp| [lp, shoelace(lp).abs] }
                     .reject { |(_, area)| area < MIN_LOOP }
        total = 0.0
        polys.each do |(ring, area)|
          depth = polys.count do |(other, _)|
            !other.equal?(ring) && point_inside?(ring[0], other)
          end
          total += depth.even? ? area : -area
        end
        total
      end

      def self.shoelace(ring)
        sum   = 0.0
        count = ring.length
        count.times do |i|
          a = ring[i]
          b = ring[(i + 1) % count]
          sum += (a.x * b.y) - (b.x * a.y)
        end
        sum / 2.0
      end

      def self.point_inside?(point, ring)
        inside = false
        count  = ring.length
        j      = count - 1
        count.times do |i|
          a = ring[i]
          b = ring[j]
          if ((a.y > point.y) != (b.y > point.y)) &&
             (point.x < (b.x - a.x) * (point.y - a.y) / (b.y - a.y) + a.x)
            inside = !inside
          end
          j = i
        end
        inside
      end

      # --- точка входа -------------------------------------------------------

      def self.run(method_key, offset_mm)
        model     = Sketchup.active_model
        anchors   = model.selection.to_a.select { |e| group_like?(e) }
        return nil if anchors.empty?

        offset  = offset_mm.to_f.mm
        roots   = anchors.map { |a| build(a, Geom::Transformation.new, method_key, offset) }
        sort_tree(roots)
        roots
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
