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

      # Шаг 5 ТЗ: планарный граф (half-edge) и внешний контур. Чистый Ruby.
      #
      # Полуребро 2k идёт a→b отрезка k, 2k+1 — обратно. В каждой вершине
      # исходящие полурёбра отсортированы по углу против часовой стрелки.
      # next(he) — следующее ПО часовой исходящее полуребро в конце he после
      # twin(he). При таком обходе ограниченные грани идут против часовой
      # (площадь > 0), а внешняя граница каждой связной компоненты — по часовой
      # (площадь < 0).
      module PlanarGraph

        # xs, ys — координаты вершин; segs — [[a, b, nx, ny], ...] без дублей.
        # Возвращает циклы: [{ vertices: [...], area: знаковая, component: корень,
        #                       edges: [номера отрезков] }]
        def self.cycles(xs, ys, segs)
          n = segs.length
          return [] if n.zero?

          origin = Array.new(2 * n)
          angle  = Array.new(2 * n)
          out    = Hash.new { |h, k| h[k] = [] }
          segs.each_with_index do |(a, b), k|
            origin[2 * k]     = a
            origin[2 * k + 1] = b
            angle[2 * k]      = Math.atan2(ys[b] - ys[a], xs[b] - xs[a])
            angle[2 * k + 1]  = Math.atan2(ys[a] - ys[b], xs[a] - xs[b])
            out[a] << 2 * k
            out[b] << 2 * k + 1
          end

          slot = Array.new(2 * n)
          out.each_value do |list|
            list.sort_by! { |he| angle[he] }
            list.each_with_index { |he, i| slot[he] = i }
          end

          # компоненты связности
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

          visited = Array.new(2 * n, false)
          result  = []
          (0...(2 * n)).each do |start|
            next if visited[start]
            verts = []
            edges = []
            he = start
            guard = 0
            until visited[he]
              visited[he] = true
              verts << origin[he]
              edges << (he >> 1)
              twin = he ^ 1
              v    = origin[twin]            # конец he
              list = out[v]
              he   = list[(slot[twin] - 1) % list.length]
              guard += 1
              break if guard > 2 * n + 1
            end
            result << {
              vertices:  verts,
              edges:     edges,
              area:      signed_area(xs, ys, verts),
              component: find.call(verts.first)
            }
          end
          result
        end

        def self.signed_area(xs, ys, verts)
          sum = 0.0
          count = verts.length
          count.times do |i|
            a = verts[i]
            b = verts[(i + 1) % count]
            sum += xs[a] * ys[b] - xs[b] * ys[a]
          end
          sum / 2.0
        end

        # Внешние границы компонент (по одной на компоненту — самый «отрицательный»
        # цикл), от большей площади к меньшей.
        def self.outer_boundaries(cycles)
          best = {}
          cycles.each do |c|
            next unless c[:area] < 0
            cur = best[c[:component]]
            best[c[:component]] = c if cur.nil? || c[:area] < cur[:area]
          end
          best.values.sort_by { |c| c[:area] }
        end

        def self.point_in_polygon?(px, py, poly)
          inside = false
          count = poly.length
          j = count - 1
          count.times do |i|
            xi, yi = poly[i]
            xj, yj = poly[j]
            if ((yi > py) != (yj > py)) &&
               (px < (xj - xi) * (py - yi) / (yj - yi) + xi)
              inside = !inside
            end
            j = i
          end
          inside
        end

      end # module PlanarGraph
    end # module Section
  end # module AreaCounter
end # module BACommunity
