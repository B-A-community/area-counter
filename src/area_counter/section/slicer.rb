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

      # Шаг 3 ТЗ: сечение граней плоскостью Z = h. Чистый Ruby, без API SketchUp.
      #
      # Вход — грани в мировых координатах:
      #   { rings: [[[x, y, z], ...], ...], normal: [nx, ny, nz] }
      # rings[0] — внешняя петля, остальные — отверстия; normal — внешняя нормаль.
      #
      # Выход — отрезки [x1, y1, x2, y2, nx, ny]: (nx, ny) — горизонтальная проекция
      # внешней нормали грани, нужна только для опции «вычитать дворы».
      module Slicer

        def self.slice(faces, h, eps)
          out = []
          faces.each { |face| slice_face(face, h, eps, out) }
          out
        end

        def self.slice_face(face, h, eps, out)
          nx, ny, = face[:normal]
          # Линия пересечения плоскости грани с Z = h: dir = normal × Z
          dx = ny
          dy = -nx
          len = Math.sqrt(dx * dx + dy * dy)
          return if len < 1.0e-9 # горизонтальная грань: плоскость её не пересекает
          dx /= len
          dy /= len

          points = []
          face[:rings].each do |ring|
            count = ring.length
            next if count < 3
            count.times do |i|
              a = ring[i]
              b = ring[(i + 1) % count]
              da = a[2] - h
              db = b[2] - h
              # Символическое возмущение: вершина на плоскости — строго выше неё.
              # Так ребро, касающееся плоскости вершиной, не даёт двойных точек.
              sa = da.abs < eps || da > 0 ? 1 : -1
              sb = db.abs < eps || db > 0 ? 1 : -1
              next if sa == sb
              denom = da - db
              t = denom.abs < 1.0e-30 ? 0.5 : da / denom
              t = 0.0 if t < 0.0
              t = 1.0 if t > 1.0
              x = a[0] + (b[0] - a[0]) * t
              y = a[1] + (b[1] - a[1]) * t
              points << [x * dx + y * dy, x, y]
            end
          end
          return if points.length < 2

          # Все точки лежат на одной прямой: сортируем вдоль неё и соединяем
          # попарно (0–1, 2–3, …) — это участки, лежащие внутри грани, с учётом дыр
          points.sort_by! { |p| p[0] }
          hn = Math.sqrt(nx * nx + ny * ny)
          snx = hn > 1.0e-12 ? nx / hn : 0.0
          sny = hn > 1.0e-12 ? ny / hn : 0.0

          i = 0
          while i + 1 < points.length
            a = points[i]
            b = points[i + 1]
            out << [a[1], a[2], b[1], b[2], snx, sny]
            i += 2
          end
        end

      end # module Slicer
    end # module Section
  end # module AreaCounter
end # module BACommunity
