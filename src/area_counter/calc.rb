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
      # Контуры мельче этого — сечения импостов, пилястр, рам: это не площадь
      # этажа, а шум рабочей модели. Двор или отдельный объём всегда крупнее.
      MIN_LOOP   = 0.5 / M2_PER_IN2

      # loops — замкнутые контуры сечения, opens — куски, которые не сошлись,
      # envelope — огибающая (пары точек), если считали по ней;
      # всё в мировых координатах, чтобы подсветка могла это нарисовать.
      Node = Struct.new(:entity, :name, :children, :area, :status, :reason,
                        :bbox, :zmin, :loops, :opens, :envelope)

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
        Node.new(entity, name_of(entity), children, area, :ok, nil, bbox, zmins.min, [], [], [])
      end

      def self.leaf(entity, tr, method_key, offset)
        @counter = (@counter || 0) + 1
        Sketchup.status_text = "area counter: обработано этажей #{@counter}" if (@counter % 25).zero?

        faces = collect_faces(inner_entities(entity), tr)
        if faces.empty?
          return Node.new(entity, name_of(entity), [], 0.0, :problem,
                          'внутри нет граней', nil, nil, [], [], [])
        end

        section = method_key.to_s == 'section'
        box, horiz, rings = scan(faces, section)
        bbox = [box.min, box.max]

        loops    = []
        opens    = []
        envelope = []
        area, status, reason =
          if section
            area, status, reason, loops, opens, envelope = section_area(rings, box.min.z + offset)
            [area, status, reason]
          else
            top_area(horiz)
          end

        Node.new(entity, name_of(entity), [], area, status, reason,
                 bbox, box.min.z, loops, opens, envelope)
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

      # Один проход по вершинам: габарит, горизонтальные грани и — для сечения —
      # все контуры граней уже в мировых координатах. Трансформация вершины
      # самая дорогая операция здесь, поэтому делается ровно один раз.
      def self.scan(faces, with_rings)
        box   = Geom::BoundingBox.new
        horiz = []
        rings = []
        faces.each do |(face, tr)|
          low  = nil
          high = nil
          outer = face.outer_loop.vertices.map do |vertex|
            point = vertex.position.transform(tr)
            box.add(point)
            z = point.z
            low  = z if low.nil?  || z < low
            high = z if high.nil? || z > high
            point
          end
          next if low.nil?
          horiz << [face, tr, (low + high) / 2.0] if (high - low) <= Z_TOL
          next unless with_rings

          face_rings = [outer]
          face.loops.each do |lp|
            next if lp.outer?
            face_rings << lp.vertices.map { |vertex| vertex.position.transform(tr) }
          end
          rings << face_rings
        end
        [box, horiz, rings]
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
      # Возвращает [площадь, статус, причина, контуры, незамкнутые куски, огибающая].
      #
      # Два прохода. Первый — сшивка отрезков в контуры: работает на солиде,
      # даёт точную площадь и вычитает дворы. Если доминирующего контура не
      # вышло (здание собрано из фасадных панелей — каждая даёт свой крошечный
      # контур, а общего нет), второй проход считает по огибающей всех отрезков.
      def self.section_area(rings, level)
        cut  = safe_cut_level(rings, level)
        segs = []
        rings.each { |face_rings| segs.concat(plane_segments(face_rings, cut)) }
        segs = unique_segments(segs)

        return [0.0, :problem, 'на отметке пусто', [], [], []] if segs.empty?

        loops, opens = chain_loops(segs, GAP)
        footprint    = segments_footprint(segs)
        biggest      = loops.map { |ring| shoelace(ring).abs }.max || 0.0

        # Контур считается доминирующим, если накрывает хотя бы четверть габарита.
        if biggest >= footprint * 0.25
          area = loops_area(loops) * M2_PER_IN2
          return [0.0, :problem, 'сечение нулевой площади', loops, opens, []] if area <= 0.0
          return [area, :problem, 'контур замкнулся не весь', loops, opens, []] unless opens.empty?
          return [area, :ok, nil, loops, [], []]
        end

        area, outline = envelope_area(segs, cut)
        return [0.0, :problem, 'контур не замкнулся', loops, opens, outline] if area <= 0.0
        # Огибающая меньше четверти габарита — значит, сомкнулись только сами
        # стены, а внутрь заливка прошла: где-то разрыв шире допуска.
        if area < footprint * M2_PER_IN2 * 0.25
          return [area, :problem, 'разрыв в контуре больше 50 мм', loops, opens, outline]
        end
        [area, :ok, 'по огибающей — дворы не вычтены', [], [], outline]
      end

      def self.segments_footprint(segs)
        xs = []
        ys = []
        segs.each { |(a, b)| xs << a.x << b.x; ys << a.y << b.y }
        (xs.max - xs.min) * (ys.max - ys.min)
      end

      # Площадь по огибающей: отрезки сечения растрируются на сетку, стенки
      # утолщаются на клетку-две, снаружи пускается заливка. Всё, куда она
      # не дошла, — здание вместе со стенами. Двор от комнаты на таком разрезе
      # не отличить, поэтому дворы здесь не вычитаются — об этом сказано
      # в причине. Возвращает [площадь м², контур огибающей как пары точек].
      def self.envelope_area(segs, cut)
        xs = []
        ys = []
        segs.each { |(a, b)| xs << a.x << b.x; ys << a.y << b.y }
        minx = xs.min; maxx = xs.max
        miny = ys.min; maxy = ys.max

        diag   = Math.sqrt((maxx - minx)**2 + (maxy - miny)**2)
        # Клетка 50–100 мм: ошибка площади в пределах полупроцента, а растр
        # остаётся в сотне тысяч клеток даже на стометровом корпусе — это
        # секунда чистого Ruby на этаж. Оборотная сторона: разрыв здесь
        # смыкается на клетку-две, то есть 100–200 мм, а не ровно 50 —
        # огибающая грубее точного пути по контуру, и это её честная цена.
        cell   = [[diag / 600.0, 50.0.mm].max, 100.0.mm].min
        radius = [(GAP / (2.0 * cell)).ceil, 1].max
        margin = radius + 2

        width  = ((maxx - minx) / cell).ceil + 2 * margin + 1
        height = ((maxy - miny) / cell).ceil + 2 * margin + 1
        return [0.0, []] if width * height > 2_000_000

        wall  = Array.new(width * height, false)
        cells = []

        # Стенки: идём вдоль каждого отрезка с шагом в полклетки
        segs.each do |(a, b)|
          len   = a.distance(b)
          steps = [(len / (cell / 2.0)).ceil, 1].max
          (0..steps).each do |s|
            t  = s.to_f / steps
            ix = ((a.x + (b.x - a.x) * t - minx) / cell).floor + margin
            iy = ((a.y + (b.y - a.y) * t - miny) / cell).floor + margin
            next if ix < 0 || ix >= width || iy < 0 || iy >= height
            idx = iy * width + ix
            next if wall[idx]
            wall[idx] = true
            cells << idx
          end
        end

        # Утолщаем стенки, чтобы сомкнуть разрывы; работаем только по клеткам
        # стен, а не по всей сетке
        thick = wall.dup
        grow(thick, cells, width, height, radius)

        # Заливка снаружи от угла — туда, где нет стенки. Попутно запоминаем
        # клетки, упёршиеся в стену: по ним потом вернём стенкам толщину.
        outside  = Array.new(width * height, false)
        queue    = [0]
        frontier = []
        outside[0] = true
        head = 0
        while head < queue.length
          idx = queue[head]
          head += 1
          ix = idx % width
          iy = idx / width
          touched = false
          [[1, 0], [-1, 0], [0, 1], [0, -1]].each do |(dx, dy)|
            nx = ix + dx
            ny = iy + dy
            next if nx < 0 || nx >= width || ny < 0 || ny >= height
            n = ny * width + nx
            next if outside[n]
            if thick[n]
              touched = true
              next
            end
            outside[n] = true
            queue << n
          end
          frontier << idx if touched
        end

        grow(outside, frontier, width, height, radius)

        inside_cells = 0
        outline = []
        z = cut
        (0...height).each do |iy|
          (0...width).each do |ix|
            idx = iy * width + ix
            next if outside[idx]
            inside_cells += 1
            x0 = minx + (ix - margin) * cell
            y0 = miny + (iy - margin) * cell
            x1 = x0 + cell
            y1 = y0 + cell
            outline << Geom::Point3d.new(x0, y0, z) << Geom::Point3d.new(x1, y0, z) if iy == 0 || outside[idx - width]
            outline << Geom::Point3d.new(x0, y1, z) << Geom::Point3d.new(x1, y1, z) if iy == height - 1 || outside[idx + width]
            outline << Geom::Point3d.new(x0, y0, z) << Geom::Point3d.new(x0, y1, z) if ix == 0 || outside[idx - 1]
            outline << Geom::Point3d.new(x1, y0, z) << Geom::Point3d.new(x1, y1, z) if ix == width - 1 || outside[idx + 1]
          end
        end

        [inside_cells * cell * cell * M2_PER_IN2, outline]
      end

      # Расширяет помеченные клетки на radius во все стороны — на месте,
      # только вокруг переданных клеток.
      def self.grow(mask, seeds, width, height, radius)
        offsets = []
        (-radius..radius).each do |dy|
          (-radius..radius).each { |dx| offsets << [dx, dy] }
        end
        seeds.each do |idx|
          ix = idx % width
          iy = idx / width
          offsets.each do |(dx, dy)|
            nx = ix + dx
            ny = iy + dy
            next if nx < 0 || nx >= width || ny < 0 || ny >= height
            mask[ny * width + nx] = true
          end
        end
        mask
      end

      # Совпавшие грани (двойные стены, дубли компонентов) дают один и тот же
      # отрезок дважды, а сшивке контура дубли рвут цепочку. Ключ по округлённым
      # координатам, чтобы не сравнивать каждый с каждым.
      def self.unique_segments(segs)
        seen = {}
        kept = []
        segs.each do |(a, b)|
          ka = [(a.x * 1000).round, (a.y * 1000).round]
          kb = [(b.x * 1000).round, (b.y * 1000).round]
          key = (ka <=> kb) <= 0 ? [ka, kb] : [kb, ka]
          next if seen[key]
          seen[key] = true
          kept << [a, b]
        end
        kept
      end

      # Вершина ровно на секущей плоскости даёт вырожденное пересечение,
      # поэтому отметку слегка сдвигаем, если она попала в вершины.
      def self.safe_cut_level(rings, cut)
        eps = 0.02.mm
        5.times do
          touching = rings.any? do |face_rings|
            face_rings.any? { |ring| ring.any? { |point| (point.z - cut).abs < eps } }
          end
          return cut unless touching
          cut += 0.05.mm
        end
        cut
      end

      # Пересечение одной грани (её контуров в мировых координатах)
      # с горизонтальной плоскостью: набор отрезков.
      def self.plane_segments(rings, cut)
        outer = rings.first
        return [] if outer.nil? || outer.length < 3

        zmin = nil
        zmax = nil
        rings.each do |ring|
          ring.each do |point|
            z = point.z
            zmin = z if zmin.nil? || z < zmin
            zmax = z if zmax.nil? || z > zmax
          end
        end
        return [] if zmax - zmin <= Z_TOL          # горизонтальная грань
        return [] if cut <= zmin || cut >= zmax    # плоскость мимо грани

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
      # Возвращает [замкнутые контуры, незамкнутые куски] — вторые нужны,
      # чтобы показать на модели, где именно сечение не сошлось.
      def self.chain_loops(segs, gap)
        # Концы отрезков раскладываем по клеткам размером с допуск: всё, что
        # ближе gap, лежит в соседних 3×3 клетках. Без этого поиск ближайшего
        # конца был перебором каждого с каждым и на тысяче отрезков занимал секунды.
        cell  = gap
        index = {}
        segs.each_with_index do |(a, b), i|
          (index[[(a.x / cell).floor, (a.y / cell).floor]] ||= []) << [i, 0]
          (index[[(b.x / cell).floor, (b.y / cell).floor]] ||= []) << [i, 1]
        end

        used  = Array.new(segs.length, false)
        loops = []
        opens = []

        segs.each_index do |start|
          next if used[start]
          used[start] = true
          poly = [segs[start][0], segs[start][1]]

          loop do
            tail    = poly.last
            closing = poly.first.distance(tail)

            best_d    = nil
            best_i    = nil
            best_flip = false
            cx = (tail.x / cell).floor
            cy = (tail.y / cell).floor
            (-1..1).each do |dy|
              (-1..1).each do |dx|
                bucket = index[[cx + dx, cy + dy]]
                next if bucket.nil?
                bucket.each do |(i, endpoint)|
                  next if used[i]
                  point = segs[i][endpoint]
                  d = tail.distance(point)
                  if best_d.nil? || d < best_d
                    best_d    = d
                    best_i    = i
                    best_flip = (endpoint == 1)
                  end
                end
              end
            end

            break if poly.length >= 3 && closing <= 1.0e-4
            break if best_i.nil? || best_d > gap

            used[best_i] = true
            seg = segs[best_i]
            poly << (best_flip ? seg[0] : seg[1])
          end

          if poly.length >= 3 && poly.first.distance(poly.last) <= gap
            loops << poly
          else
            opens << poly
          end
        end

        [loops, opens]
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
