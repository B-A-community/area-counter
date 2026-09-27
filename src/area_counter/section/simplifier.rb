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

      # Шаг 6 ТЗ: упрощение контура и шаг 7 — проверка на самопересечение.
      # Чистый Ruby. Контур — [[x, y], ...], замкнут неявно.
      #
      # Снимаются только вершины на прямых (излом < 0,01° или отклонение от
      # прямой < tol/2) и микро-шипы (возврат назад на отрезке < tol). Никаких
      # выпуклых оболочек и Дугласа — Пекера с большим допуском: контур обязан
      # повторять пластику.
      module Simplifier

        ANGLE_DEG = 0.01

        def self.simplify(ring, tol)
          pts = ring.map { |p| [p[0], p[1]] }
          loop do
            changed = false
            i = 0
            while pts.length > 3 && i < pts.length
              a = pts[i - 1]
              b = pts[i]
              c = pts[(i + 1) % pts.length]
              if redundant?(a, b, c, tol)
                pts.delete_at(i)
                changed = true
              else
                i += 1
              end
            end
            break unless changed
          end
          pts
        end

        def self.redundant?(a, b, c, tol)
          abx = b[0] - a[0]
          aby = b[1] - a[1]
          bcx = c[0] - b[0]
          bcy = c[1] - b[1]
          ab = Math.sqrt(abx * abx + aby * aby)
          bc = Math.sqrt(bcx * bcx + bcy * bcy)
          return true if ab < 1.0e-9 || bc < 1.0e-9

          cos = (abx * bcx + aby * bcy) / (ab * bc)
          cos = 1.0 if cos > 1.0
          cos = -1.0 if cos < -1.0

          if cos > 0.0
            # идём почти прямо: излом крошечный или вершина у самой прямой
            return true if Math.acos(cos) * 180.0 / Math::PI < ANGLE_DEG
            return true if segment_distance(b, a, c) < tol / 2.0
            false
          else
            # возврат назад — шип; снимаем, если короткий
            [ab, bc].min < tol
          end
        end

        def self.segment_distance(p, a, b)
          dx = b[0] - a[0]
          dy = b[1] - a[1]
          len2 = dx * dx + dy * dy
          t = len2 < 1.0e-18 ? 0.0 : ((p[0] - a[0]) * dx + (p[1] - a[1]) * dy) / len2
          t = 0.0 if t < 0.0
          t = 1.0 if t > 1.0
          Math.sqrt((p[0] - a[0] - t * dx)**2 + (p[1] - a[1] - t * dy)**2)
        end

        def self.area(ring)
          sum = 0.0
          count = ring.length
          count.times do |i|
            a = ring[i]
            b = ring[(i + 1) % count]
            sum += a[0] * b[1] - b[0] * a[1]
          end
          sum / 2.0
        end

        # Шаг 7: контур не самопересекается и не касается сам себя вершиной.
        # Несоседние рёбра проверяются через сетку ячеек.
        def self.self_intersecting?(ring, tol)
          n = ring.length
          return true if n < 3

          seen = {}
          ring.each do |(x, y)|
            key = [(x / tol).round, (y / tol).round]
            return true if seen[key]
            seen[key] = true
          end

          xs = ring.map { |p| p[0] }
          ys = ring.map { |p| p[1] }
          ext  = [xs.max - xs.min, ys.max - ys.min, tol].max
          cell = [ext / Math.sqrt(n) * 2.0, tol * 10.0].max
          grid = {}
          n.times do |i|
            a = ring[i]
            b = ring[(i + 1) % n]
            ([a[0], b[0]].min / cell).floor.upto(([a[0], b[0]].max / cell).floor) do |cx|
              ([a[1], b[1]].min / cell).floor.upto(([a[1], b[1]].max / cell).floor) do |cy|
                (grid[[cx, cy]] ||= []) << i
              end
            end
          end

          grid.each_value do |list|
            list.each_with_index do |i, p|
              list[(p + 1)..-1].each do |j|
                next if j == i
                next if (i - j).abs == 1 || (i - j).abs == n - 1
                return true if cross?(ring[i], ring[(i + 1) % n], ring[j], ring[(j + 1) % n])
              end
            end
          end
          false
        end

        def self.cross?(p1, p2, q1, q2)
          d1 = orient(q1, q2, p1)
          d2 = orient(q1, q2, p2)
          d3 = orient(p1, p2, q1)
          d4 = orient(p1, p2, q2)
          ((d1 > 0 && d2 < 0) || (d1 < 0 && d2 > 0)) &&
            ((d3 > 0 && d4 < 0) || (d3 < 0 && d4 > 0))
        end

        def self.orient(a, b, c)
          (b[0] - a[0]) * (c[1] - a[1]) - (b[1] - a[1]) * (c[0] - a[0])
        end

      end # module Simplifier
    end # module Section
  end # module AreaCounter
end # module BACommunity
