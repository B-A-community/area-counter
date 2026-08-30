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
    module Calc

      M2_PER_IN2 = 0.00064516   # 1 кв. дюйм в кв. метрах
      Z_TOL      = 1.0.mm       # допуск «одна и та же отметка»
      GAP        = 50.0.mm      # разрыв, который считаем одной стеной (В5)
      MIN_LOOP   = 0.01 / M2_PER_IN2  # контуры мельче 0.01 м² — это мусор

      Node = Struct.new(:entity, :name, :children, :area, :status, :reason, :bbox, :zmin)

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

      def self.child_groups(entity)
        inner_entities(entity).select { |e| group_like?(e) && shown?(e) }
      end

      # --- обход -------------------------------------------------------------

      # depth — сколько уровней вниз от якоря лежат этажи.
      # 0 — выделены сами этажи, 1 — выделен корпус, 2 — квартал.
      def self.build(entity, parent_tr, depth, method_key, offset)
        tr = parent_tr * entity.transformation

        return leaf(entity, tr, method_key, offset) if depth <= 0

        kids = child_groups(entity)
        # Глубже, чем есть, не лезем: якорь просто оказывается этажом сам.
        return leaf(entity, tr, method_key, offset) if kids.empty?

        children = kids.map { |kid| build(kid, tr, depth - 1, method_key, offset) }
        branch(entity, children)
      end

      def self.branch(entity, children)
        area  = children.inject(0.0) { |sum, node| sum + node.area.to_f }
        boxes = children.map(&:bbox).compact
        bbox  = boxes.empty? ? nil : union_bbox(boxes)
        zmins = children.map(&:zmin).compact
        Node.new(entity, name_of(entity), children, area, :ok, nil, bbox, zmins.min)
      end

      def self.leaf(entity, tr, method_key, offset)
        @counter = (@counter || 0) + 1
        Sketchup.status_text = "area counter: обработано этажей #{@counter}" if (@counter % 25).zero?

        faces = collect_faces(inner_entities(entity), tr)
        if faces.empty?
          return Node.new(entity, name_of(entity), [], 0.0, :problem,
                          'внутри нет граней', nil, nil)
        end

        box, horiz = scan(faces)
        bbox = [box.min, box.max]

        area, status, reason =
          if method_key.to_s == 'section'
            section_area(faces, box.min.z + offset)
          else
            top_area(horiz)
          end

        Node.new(entity, name_of(entity), [], area, status, reason, bbox, box.min.z)
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
            collect_faces(entity.entities, tr * entity.transformation, acc) if shown?(entity)
          elsif klass == Sketchup::ComponentInstance
            collect_faces(entity.definition.entities, tr * entity.transformation, acc) if shown?(entity)
          end
        end
        acc
      end

      # Один проход по граням: сразу и габарит, и горизонтальные грани.
      # Раньше вершины пересчитывались дважды — на больших этажах это вдвое дороже.
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
        return [0.0, :problem, 'нет горизонтальных граней'] if horiz.empty?

        top    = horiz.map { |item| item[2] }.max
        on_top = horiz.select { |item| (top - item[2]).abs <= Z_TOL }
        in2    = on_top.inject(0.0) { |sum, item| sum + item[0].area(item[1]) }
        area   = in2 * M2_PER_IN2

        return [0.0, :problem, 'верхняя грань нулевой площади'] if area <= 0.0
        [area, :ok, nil]
      end

      # --- способ 2: горизонтальное сечение на отметке -----------------------
      #
      # Модель не трогаем: сечение считается аналитически по граням.
      # Отметка отмеряется от низа группы-этажа (В3), внутренние дворы
      # вычитаются вложенностью контуров (В4), разрывы до 50 мм смыкаются (В5).
      def self.section_area(faces, level)
        cut  = safe_cut_level(faces, level)
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
            face.outer_loop.vertices.each do |vertex|
              if (vertex.position.transform(tr).z - cut).abs < eps
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
        return [] if outer.length < 3

        rings = face.loops.map { |lp| lp.vertices.map { |v| v.position.transform(tr) } }
        all   = rings.inject([]) { |acc, ring| acc + ring }

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

        segs  = []
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
        points.each do |point|
          kept << point unless kept.any? { |other| other.distance(point) <= tol }
        end
        kept
      end

      # Сшивает отрезки в замкнутые контуры, прощая разрывы до gap.
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

            best_d    = nil
            best_i    = nil
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

            break if poly.length >= 3 && closing <= 1.0e-4

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

      def self.run(method_key, offset_mm, depth)
        model   = Sketchup.active_model
        anchors = model.selection.to_a.select { |e| group_like?(e) }
        return nil if anchors.empty?

        reset_cache
        @counter = 0
        Sketchup.status_text = 'area counter: считаю…'

        offset = offset_mm.to_f.mm
        roots  = anchors.map { |a| build(a, Geom::Transformation.new, depth.to_i, method_key, offset) }
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
