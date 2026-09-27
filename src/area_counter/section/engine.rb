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

      # Сборка шагов 2–7 ТЗ: высота реза, сечение, очистка, граф, упрощение,
      # проверка и перебор высот. Всё в дюймах (внутренние единицы SketchUp).
      #
      # compute — чистый Ruby: принимает то, что собрал Traversal, и потому
      # проверяется без SketchUp. section — обёртка для живой модели.
      module Engine

        MM         = 1.0 / 25.4
        M2_PER_IN2 = 0.00064516
        EPS        = 0.01 * MM     # «вершина на плоскости»
        FLAT_EPS   = 0.1 * MM      # «горизонтальная грань лежит в плоскости реза»
        SHIFT      = 2.0 * MM      # на сколько уводим рез с такой грани
        FRAGMENT_M2 = 0.1

        DEFAULTS = {
          cut_mm:         1000.0,
          snap_mm:        1.0,
          gap_mm:         20.0,
          ignore_hidden:  true,
          subtract_holes: false
        }.freeze

        # Высоты для перебора, если на заданной кольцо фасада разорвано
        SEARCH_MM = [300, 500, 800, 1000, 1200, 1500, 1800, 2100, 2400, 2700, 3000, 3500, 4000].freeze

        def self.options(opts)
          o = DEFAULTS.dup
          (opts || {}).each { |k, v| o[k.to_sym] = v unless v.nil? }
          o
        end

        def self.section(entity, world_tr, opts = {})
          o = options(opts)
          data = Traversal.collect(entity, world_tr, o[:ignore_hidden])
          return empty(AreaCounter.t(:no_faces), nil) if data[:bbox].nil?
          compute(data, o)
        end

        # data — { faces:, flats:, bbox: [minx, miny, minz, maxx, maxy, maxz] }
        def self.compute(data, opts)
          o    = options(opts)
          box  = data[:bbox]
          zmin = box[2]
          span = box[5] - box[2]
          snap = o[:snap_mm].to_f * MM
          gap  = o[:gap_mm].to_f * MM
          user = o[:cut_mm].to_f * MM

          first = attempt(data, zmin + user, snap, gap, o)
          return finish(first, user, nil) if first[:passed]

          # Шаг 7: кольцо фасада, похоже, разорвано — ищем высоту, где оно цело
          SEARCH_MM.each do |mm|
            h = mm * MM
            next if (h - user).abs < 1.0e-6
            next if h >= span - 50.0 * MM
            r = attempt(data, zmin + h, snap, gap, o)
            return finish(r, user, mm) if r[:passed]
          end

          first[:status] = :problem
          first[:warnings].unshift(AreaCounter.t(:w_ring_broken)) if first[:contour]
          finish(first, user, nil)
        end

        def self.finish(result, user, searched_mm)
          used_mm = (result[:height] - result[:bbox][2]) / MM
          result[:cut_mm] = used_mm
          if searched_mm
            result[:warnings].unshift(AreaCounter.t(:w_cut_other, used_mm.round, (user / MM).round))
          elsif (used_mm - user / MM).abs > 0.01
            result[:warnings].unshift(AreaCounter.t(:w_cut_shifted, used_mm.round))
          end
          result[:reason] = result[:warnings].empty? ? nil : result[:warnings].join('; ')
          result
        end

        def self.empty(reason, bbox)
          { area_m2: 0.0, status: :problem, warnings: [reason], reason: reason,
            contour: nil, holes: [], fragments: [], whiskers: [], passed: false,
            height: bbox ? bbox[2] : 0.0, bbox: bbox || [0, 0, 0, 0, 0, 0] }
        end

        # Шаг 2: рез не должен совпадать с плитой, подоконником, торцом
        def self.clear_of_flats(h, flats)
          20.times do
            break unless flats.any? { |z| (z - h).abs < FLAT_EPS }
            h += SHIFT
          end
          h
        end

        def self.attempt(data, h, snap, gap, o)
          box = data[:bbox]
          h = clear_of_flats(h, data[:flats])
          base = { height: h, bbox: box, warnings: [], holes: [], fragments: [],
                   whiskers: [], contour: nil, passed: false, area_m2: 0.0 }

          faces = data[:faces].select { |f| f[:zmin] <= h + EPS && f[:zmax] >= h - EPS }
          raw   = Slicer.slice(faces, h, EPS)
          if raw.empty?
            base[:status] = :problem
            base[:warnings] << AreaCounter.t(:w_empty)
            return base
          end

          clean = SegmentCleaner.clean(raw, snap, gap)
          xs = clean[:xs]
          ys = clean[:ys]
          base[:whiskers] = clean[:whiskers]

          outers = PlanarGraph.outer_boundaries(PlanarGraph.cycles(xs, ys, clean[:segs]))
          if outers.empty?
            base[:status] = :problem
            base[:warnings] << AreaCounter.t(:w_not_closed)
            return base
          end

          main = ring_of(outers.first, xs, ys, snap)
          main_area = Simplifier.area(main)

          holes_area = 0.0
          outers.drop(1).each do |cycle|
            ring = ring_of(cycle, xs, ys, snap)
            px, py = ring.first
            if PlanarGraph.point_in_polygon?(px, py, main)
              next unless o[:subtract_holes]
              next unless void?(cycle, xs, ys, clean[:segs], snap)
              next if base[:holes].any? { |hole| PlanarGraph.point_in_polygon?(px, py, hole) }
              base[:holes] << ring
              holes_area += Simplifier.area(ring)
            elsif Simplifier.area(ring) * M2_PER_IN2 > FRAGMENT_M2
              base[:fragments] << ring
            end
          end

          base[:contour] = main
          base[:area_m2] = (main_area - holes_area) * M2_PER_IN2
          unless base[:fragments].empty?
            frag = base[:fragments].inject(0.0) { |s, r| s + Simplifier.area(r) } * M2_PER_IN2
            base[:warnings] << AreaCounter.t(:w_fragments, base[:fragments].length, AreaCounter.decimal(frag))
          end

          if Simplifier.self_intersecting?(main, snap)
            base[:status] = :problem
            base[:warnings] << AreaCounter.t(:w_self_cross)
            return base
          end

          # Санити-чек на разрыв кольца фасада
          bbox_area = (box[3] - box[0]) * (box[4] - box[1])
          cx = (box[0] + box[3]) / 2.0
          cy = (box[1] + box[4]) / 2.0
          base[:passed] = main_area >= 0.5 * bbox_area && PlanarGraph.point_in_polygon?(cx, cy, main)
          base[:status] = :ok
          base
        end

        # Контур цикла: упрощённый и против часовой стрелки
        def self.ring_of(cycle, xs, ys, snap)
          ring = Simplifier.simplify(cycle[:vertices].map { |v| [xs[v], ys[v]] }, snap)
          ring.reverse! if Simplifier.area(ring) < 0
          ring
        end

        # Для опции «вычитать дворы»: внутренний контур — пустота, если внешние
        # нормали его стен смотрят внутрь него (стены двора), и материал — если
        # наружу (колонна, шахта-солид). Берём самую длинную стену контура.
        def self.void?(cycle, xs, ys, segs, snap)
          best = nil
          cycle[:edges].uniq.each do |k|
            a, b, nx, ny = segs[k]
            next if nx.to_f.abs + ny.to_f.abs < 1.0e-9
            len = Math.hypot(xs[b] - xs[a], ys[b] - ys[a])
            best = [len, a, b, nx, ny] if best.nil? || len > best[0]
          end
          return false unless best
          _, a, b, nx, ny = best
          probe = [snap * 3.0, best[0] / 4.0].min
          px = (xs[a] + xs[b]) / 2.0 + nx * probe
          py = (ys[a] + ys[b]) / 2.0 + ny * probe
          poly = cycle[:vertices].map { |v| [xs[v], ys[v]] }
          PlanarGraph.point_in_polygon?(px, py, poly)
        end

      end # module Engine
    end # module Section
  end # module AreaCounter
end # module BACommunity
