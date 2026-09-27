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

module BACommunity
  module AreaCounter
    module Section

      # Шаг 4 ТЗ: очистка набора отрезков. Чистый Ruby, без API SketchUp.
      #
      # Отрезок внутри — [a, b, nx, ny]: a, b — номера вершин в пуле,
      # (nx, ny) — нормаль исходной грани, едет за отрезком при разбиении.
      module SegmentCleaner

        # Пул вершин со сваркой: точки ближе tol становятся одной вершиной.
        # Сетка с шагом tol и просмотром соседних ячеек — чтобы точки по разные
        # стороны границы ячейки не разъехались.
        class VertexPool
          attr_reader :xs, :ys

          def initialize(tol)
            @tol2 = tol * tol
            @cell = tol > 0 ? tol : 1.0e-9
            @grid = {}
            @xs   = []
            @ys   = []
          end

          def add(x, y)
            cx = (x / @cell).floor
            cy = (y / @cell).floor
            best = nil
            best_d = @tol2
            (cx - 1).upto(cx + 1) do |gx|
              (cy - 1).upto(cy + 1) do |gy|
                bucket = @grid[gx * 4_294_967_296 + gy]
                next unless bucket
                bucket.each do |id|
                  d = (@xs[id] - x)**2 + (@ys[id] - y)**2
                  if d <= best_d
                    best_d = d
                    best = id
                  end
                end
              end
            end
            return best if best

            id = @xs.length
            @xs << x
            @ys << y
            (@grid[cx * 4_294_967_296 + cy] ||= []) << id
            id
          end

          def size
            @xs.length
          end
        end

        # raw — отрезки [x1, y1, x2, y2, nx, ny] из Slicer.
        # Возвращает { xs:, ys:, segs: [[a, b, nx, ny]], whiskers: [[x1, y1, x2, y2]] }.
        def self.clean(raw, snap_tol, gap_tol)
          pool = VertexPool.new(snap_tol)
          segs = raw.map do |(x1, y1, x2, y2, nx, ny)|
            [pool.add(x1, y1), pool.add(x2, y2), nx, ny]
          end
          segs = dedupe(segs, pool.size)
          segs = split(pool, segs, snap_tol)

          # Закрытие зазоров сдвигает вершины — после него сварка и разбиение заново
          if gap_tol > 0 && !segs.empty?
            xs = pool.xs.dup
            ys = pool.ys.dup
            snap_dangling(xs, ys, segs, gap_tol)
            snap_components(xs, ys, segs, gap_tol)
            pool, segs = reweld(xs, ys, segs, snap_tol)
            segs = split(pool, segs, snap_tol)
          end

          segs, whiskers = prune(pool.xs, pool.ys, segs)
          { xs: pool.xs, ys: pool.ys, segs: segs, whiskers: whiskers }
        end

        # --- удаление нулевых и дублей ----------------------------------------

        def self.dedupe(segs, nverts)
          seen = {}
          out  = []
          base = nverts + 1
          segs.each do |seg|
            a = seg[0]
            b = seg[1]
            next if a == b
            key = a < b ? a * base + b : b * base + a
            next if seen[key]
            seen[key] = true
            out << seg
          end
          out
        end

        # --- разбиение в пересечениях, Т-стыках и перекрытиях -----------------
        #
        # Пары отрезков ищутся через сетку ячеек, а не перебором каждого с
        # каждым; пару проверяем только в первой общей ячейке, чтобы не дважды.
        def self.split(pool, segs, tol)
          4.times do
            n = segs.length
            return segs if n < 2
            xs = pool.xs
            ys = pool.ys

            minx = miny = Float::INFINITY
            maxx = maxy = -Float::INFINITY
            segs.each do |(a, b)|
              [a, b].each do |v|
                minx = xs[v] if xs[v] < minx
                maxx = xs[v] if xs[v] > maxx
                miny = ys[v] if ys[v] < miny
                maxy = ys[v] if ys[v] > maxy
              end
            end
            ext  = [maxx - minx, maxy - miny, tol].max
            cell = [ext / Math.sqrt(n) * 2.0, tol * 20.0].max

            grid   = {}
            ranges = Array.new(n)
            segs.each_with_index do |(a, b), i|
              cx0 = (([xs[a], xs[b]].min - tol - minx) / cell).floor
              cx1 = (([xs[a], xs[b]].max + tol - minx) / cell).floor
              cy0 = (([ys[a], ys[b]].min - tol - miny) / cell).floor
              cy1 = (([ys[a], ys[b]].max + tol - miny) / cell).floor
              ranges[i] = [cx0, cy0, cx1, cy1]
              cx0.upto(cx1) do |cx|
                cy0.upto(cy1) { |cy| (grid[[cx, cy]] ||= []) << i }
              end
            end

            splits = {}
            grid.each do |(cx, cy), list|
              next if list.length < 2
              last = list.length - 1
              0.upto(last - 1) do |p|
                i  = list[p]
                ri = ranges[i]
                (p + 1).upto(last) do |q|
                  j  = list[q]
                  rj = ranges[j]
                  lx = ri[0] > rj[0] ? ri[0] : rj[0]
                  ly = ri[1] > rj[1] ? ri[1] : rj[1]
                  next unless lx == cx && ly == cy
                  interact(pool, segs, i, j, tol, splits)
                end
              end
            end

            return dedupe(segs, pool.size) if splits.empty?

            out = []
            segs.each_with_index do |seg, i|
              extra = splits[i]
              unless extra
                out << seg
                next
              end
              a, b, nx, ny = seg
              ax = xs[a]
              ay = ys[a]
              dx = xs[b] - ax
              dy = ys[b] - ay
              ids = extra.uniq.sort_by { |v| (xs[v] - ax) * dx + (ys[v] - ay) * dy }
              chain = [a] + ids + [b]
              0.upto(chain.length - 2) do |k|
                out << [chain[k], chain[k + 1], nx, ny] if chain[k] != chain[k + 1]
              end
            end
            segs = dedupe(out, pool.size)
          end
          segs
        end

        def self.interact(pool, segs, i, j, tol, splits)
          xs = pool.xs
          ys = pool.ys
          a1, a2 = segs[i]
          b1, b2 = segs[j]

          touched = false
          # Конец одного отрезка лежит на другом (Т-стык, перекрытие коллинеарных)
          [[a1, j, b1, b2], [a2, j, b1, b2], [b1, i, a1, a2], [b2, i, a1, a2]].each do |(v, target, t1, t2)|
            next if v == t1 || v == t2
            next unless on_segment?(xs, ys, v, t1, t2, tol)
            (splits[target] ||= []) << v
            touched = true
          end
          return if touched
          return if a1 == b1 || a1 == b2 || a2 == b1 || a2 == b2

          # Собственное пересечение внутренностей
          rx = xs[a2] - xs[a1]
          ry = ys[a2] - ys[a1]
          sx = xs[b2] - xs[b1]
          sy = ys[b2] - ys[b1]
          denom = rx * sy - ry * sx
          return if denom.abs < 1.0e-18
          qx = xs[b1] - xs[a1]
          qy = ys[b1] - ys[a1]
          t = (qx * sy - qy * sx) / denom
          u = (qx * ry - qy * rx) / denom
          return if t <= 0.0 || t >= 1.0 || u <= 0.0 || u >= 1.0
          px = xs[a1] + t * rx
          py = ys[a1] + t * ry
          id = pool.add(px, py)
          (splits[i] ||= []) << id unless id == a1 || id == a2
          (splits[j] ||= []) << id unless id == b1 || id == b2
        end

        # Вершина v лежит на внутренности отрезка (s1, s2) с допуском tol
        def self.on_segment?(xs, ys, v, s1, s2, tol)
          px = xs[v]
          py = ys[v]
          ax = xs[s1]
          ay = ys[s1]
          dx = xs[s2] - ax
          dy = ys[s2] - ay
          len2 = dx * dx + dy * dy
          return false if len2 < 1.0e-18
          t = ((px - ax) * dx + (py - ay) * dy) / len2
          return false if t <= 0.0 || t >= 1.0
          len = Math.sqrt(len2)
          return false if t * len <= tol || (1.0 - t) * len <= tol
          cx = ax + t * dx
          cy = ay + t * dy
          (px - cx)**2 + (py - cy)**2 <= tol * tol
        end

        # --- закрытие зазоров --------------------------------------------------

        def self.segment_grid(xs, ys, segs, cell)
          grid = {}
          segs.each_with_index do |(a, b), i|
            cx0 = ([xs[a], xs[b]].min / cell).floor
            cx1 = ([xs[a], xs[b]].max / cell).floor
            cy0 = ([ys[a], ys[b]].min / cell).floor
            cy1 = ([ys[a], ys[b]].max / cell).floor
            cx0.upto(cx1) { |cx| cy0.upto(cy1) { |cy| (grid[[cx, cy]] ||= []) << i } }
          end
          grid
        end

        def self.nearby(grid, cell, x, y, radius)
          seen = {}
          out  = []
          ((x - radius) / cell).floor.upto(((x + radius) / cell).floor) do |cx|
            ((y - radius) / cell).floor.upto(((y + radius) / cell).floor) do |cy|
              bucket = grid[[cx, cy]]
              next unless bucket
              bucket.each do |i|
                next if seen[i]
                seen[i] = true
                out << i
              end
            end
          end
          out
        end

        # Ближайшая точка отрезка к (px, py): [расстояние², x, y]
        def self.closest(xs, ys, a, b, px, py)
          ax = xs[a]
          ay = ys[a]
          dx = xs[b] - ax
          dy = ys[b] - ay
          len2 = dx * dx + dy * dy
          t = len2 < 1.0e-18 ? 0.0 : ((px - ax) * dx + (py - ay) * dy) / len2
          t = 0.0 if t < 0.0
          t = 1.0 if t > 1.0
          cx = ax + t * dx
          cy = ay + t * dy
          [(px - cx)**2 + (py - cy)**2, cx, cy]
        end

        # Висячая вершина (степень 1) защёлкивается на ближайшую вершину или
        # отрезок в пределах gap_tol — кроме своего отрезка.
        def self.snap_dangling(xs, ys, segs, gap_tol)
          degree = Hash.new(0)
          own    = {}
          segs.each_with_index do |(a, b), i|
            degree[a] += 1
            degree[b] += 1
            own[a] = i
            own[b] = i
          end
          dangling = degree.select { |_, d| d == 1 }.keys
          return if dangling.empty?

          cell = gap_tol * 4.0
          grid = segment_grid(xs, ys, segs, cell)
          gap2 = gap_tol * gap_tol
          dangling.each do |v|
            mine = own[v]
            partner = segs[mine][0] == v ? segs[mine][1] : segs[mine][0]
            best = nil
            nearby(grid, cell, xs[v], ys[v], gap_tol * 2).each do |i|
              next if i == mine
              a, b = segs[i]
              next if a == v || b == v
              d2, cx, cy = closest(xs, ys, a, b, xs[v], ys[v])
              next if d2 > gap2
              # Не защёлкиваемся в собственного соседа — это схлопнуло бы свой отрезок
              next if (cx - xs[partner])**2 + (cy - ys[partner])**2 < 1.0e-18
              best = [d2, cx, cy] if best.nil? || d2 < best[0]
            end
            next unless best
            xs[v] = best[1]
            ys[v] = best[2]
          end
        end

        # Отдельные куски (пилястра в 5 мм от стены, панели с зазором) защёлкиваются
        # на более крупные: их вершины в пределах gap_tol переносятся на ближайший
        # отрезок уже закреплённых кусков. Крупный кусок не двигается никогда.
        def self.snap_components(xs, ys, segs, gap_tol)
          parent = {}
          find = lambda do |v|
            parent[v] ||= v
            root = v
            root = parent[root] while parent[root] != root
            while parent[v] != root
              nxt = parent[v]
              parent[v] = root
              v = nxt
            end
            root
          end
          segs.each do |(a, b)|
            ra = find.call(a)
            rb = find.call(b)
            parent[ra] = rb if ra != rb
          end

          members = Hash.new { |h, k| h[k] = [] }
          parent.keys.each { |v| members[find.call(v)] << v }
          return if members.length < 2

          size = {}
          members.each do |root, vs|
            bx = vs.map { |v| xs[v] }
            by = vs.map { |v| ys[v] }
            size[root] = (bx.max - bx.min) * (by.max - by.min) + vs.length * 1.0e-12
          end
          order = members.keys.sort_by { |root| -size[root] }

          seg_root = segs.map { |(a, _)| find.call(a) }
          cell = gap_tol * 4.0
          grid = segment_grid(xs, ys, segs, cell)
          gap2 = gap_tol * gap_tol
          fixed = { order.first => true }

          order.drop(1).each do |root|
            members[root].each do |v|
              best = nil
              nearby(grid, cell, xs[v], ys[v], gap_tol * 3).each do |i|
                next unless fixed[seg_root[i]]
                a, b = segs[i]
                d2, cx, cy = closest(xs, ys, a, b, xs[v], ys[v])
                next if d2 > gap2
                best = [d2, cx, cy] if best.nil? || d2 < best[0]
              end
              next unless best
              xs[v] = best[1]
              ys[v] = best[2]
            end
            fixed[root] = true
          end
        end

        # Пересварка после сдвигов: совпавшие вершины сливаются
        def self.reweld(xs, ys, segs, snap_tol)
          pool = VertexPool.new(snap_tol)
          map  = {}
          out  = segs.map do |(a, b, nx, ny)|
            map[a] ||= pool.add(xs[a], ys[a])
            map[b] ||= pool.add(xs[b], ys[b])
            [map[a], map[b], nx, ny]
          end
          [pool, dedupe(out, pool.size)]
        end

        # --- удаление «усов» -------------------------------------------------

        # Итеративно снимаем вершины степени 1 вместе с их отрезком.
        # Снятое возвращается отдельно — подсветка покажет, где контур не сошёлся.
        def self.prune(xs, ys, segs)
          adj = Hash.new { |h, k| h[k] = [] }
          segs.each_with_index do |(a, b), i|
            adj[a] << i
            adj[b] << i
          end
          alive  = Array.new(segs.length, true)
          degree = {}
          adj.each { |v, list| degree[v] = list.length }
          queue = degree.select { |_, d| d == 1 }.keys

          until queue.empty?
            v = queue.pop
            next unless degree[v] == 1
            i = adj[v].find { |k| alive[k] }
            next unless i
            alive[i] = false
            a, b = segs[i]
            degree[a] -= 1
            degree[b] -= 1
            other = a == v ? b : a
            queue << other if degree[other] == 1
          end

          kept     = []
          whiskers = []
          segs.each_with_index do |seg, i|
            if alive[i]
              kept << seg
            else
              whiskers << [xs[seg[0]], ys[seg[0]], xs[seg[1]], ys[seg[1]]]
            end
          end
          [kept, whiskers]
        end

      end # module SegmentCleaner
    end # module Section
  end # module AreaCounter
end # module BACommunity
