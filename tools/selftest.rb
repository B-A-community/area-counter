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

# Самопроверка area counter: модули сечения по отдельности, 10 тест-кейсов ТЗ
# «чистое сечение этажа», верхняя грань, иерархия и таблицы.
#
# Запуск из Ruby Console SketchUp при загруженном плагине:
#   load 'C:/путь/к/репозиторию/tools/selftest.rb'
#   BACommunity::AreaCounter::SelfTest.run
#
# Фигуры строятся в 300 м от начала координат. Расчётные тесты идут внутри
# операции, которая откатывается; тесты создания грани в модели убирают
# за собой всё созданное. Модель остаётся такой, какой была.

module BACommunity
  module AreaCounter
    module SelfTest

      OFFSET = 300.m
      MM     = 1.0 / 25.4
      S      = Section

      def self.opts(extra = {})
        { cut_mm: 1000.0, snap_mm: 1.0, gap_mm: 20.0,
          ignore_hidden: true, subtract_holes: false }.merge(extra)
      end

      def self.run
        model = Sketchup.active_model
        results = []
        begin
          units(results)
          model.start_operation('area counter: самопроверка', true)
          begin
            scenarios(model, results)
          ensure
            model.active_path = nil if model.respond_to?(:active_path=) && model.active_path
            model.abort_operation
          end
          builder_tests(model, results)
        rescue StandardError => e
          results << "CRASH #{e.class}: #{e.message} @ #{e.backtrace.first(3).join(' | ')}"
        end
        summary = results.join("\n")
        puts summary
        summary
      end

      # --- чистые модули, без модели --------------------------------------

      def self.units(out)
        # Ориентация циклов: внешняя граница по часовой (площадь < 0)
        xs = [0.0, 10.0, 10.0, 0.0]
        ys = [0.0, 0.0, 10.0, 10.0]
        segs = [[0, 1, 0, 0], [1, 2, 0, 0], [2, 3, 0, 0], [3, 0, 0, 0]]
        areas = S::PlanarGraph.cycles(xs, ys, segs).map { |c| c[:area] }.sort
        verdict(out, areas == [-100.0, 100.0], "U1 квадрат: циклы #{areas.inspect}, внешний отрицательный")

        # ТЗ-5: грань с отверстием, рез через отверстие
        face = { rings: [[[0, 0, 0], [10, 0, 0], [10, 0, 3], [0, 0, 3]],
                         [[4, 0, 0.8], [4, 0, 2.3], [6, 0, 2.3], [6, 0, 0.8]]],
                 normal: [0, -1, 0] }
        segs = S::Slicer.slice([face], 1.0, 1.0e-6).map { |s| [s[0], s[2]].sort }.sort
        verdict(out, segs == [[0.0, 4.0], [6.0, 10.0]], "ТЗ-5 грань с окном: отрезки #{segs.inspect}")

        # Вершина ровно на плоскости не даёт двойных точек
        tri = { rings: [[[0, 0, 0], [10, 0, 1], [0, 0, 2]]], normal: [0, -1, 0] }
        segs = S::Slicer.slice([tri], 1.0, 1.0e-6)
        verdict(out, segs.length == 1, "U2 вершина на плоскости: отрезков #{segs.length} (ожидался 1)")

        # Прямоугольники со стыком → один контур из 4 вершин
        raw = rect_segs(0, 0, 5, 10) + rect_segs(5, 0, 10, 10)
        ring, count = outer_ring(raw, 1 * MM, 20 * MM)
        verdict(out, ring.length == 4 && (S::Simplifier.area(ring) - 100).abs < 1.0e-9,
                "U3 стык панелей: вершин #{ring.length}, площадь #{S::Simplifier.area(ring)}, контуров #{count}")

        # Упрощение: вершины на прямой и шип уходят, угол остаётся
        pts = [[0, 0], [5, 0], [10, 0], [10, 5], [10, 5.00001], [10, 10], [0, 10]]
        simple = S::Simplifier.simplify(pts, 1 * MM)
        verdict(out, simple.length == 4, "U4 упрощение: #{simple.length} вершины (ожидалось 4)")
      end

      def self.rect_segs(x0, y0, x1, y1)
        [[x0, y0, x1, y0], [x1, y0, x1, y1], [x1, y1, x0, y1], [x0, y1, x0, y0]].map { |s| s + [0.0, 0.0] }
      end

      def self.outer_ring(raw, snap, gap)
        c = S::SegmentCleaner.clean(raw, snap, gap)
        outers = S::PlanarGraph.outer_boundaries(S::PlanarGraph.cycles(c[:xs], c[:ys], c[:segs]))
        ring = S::Simplifier.simplify(outers.first[:vertices].map { |v| [c[:xs][v], c[:ys][v]] }, snap)
        ring.reverse! if S::Simplifier.area(ring) < 0
        [ring, outers.length]
      end

      # --- сценарии на модели (откатываются) -------------------------------

      def self.scenarios(model, out)
        ents = model.entities
        x = OFFSET

        # ТЗ-1: куб 10×10 → ровно 100 м², 4 вершины
        g = box(ents, x, 0, 0, 10.m, 10.m, 3.m, 'ТЗ-1')
        r = section(g, opts)
        check(out, 'ТЗ-1 куб 10×10, площадь', r[:area_m2], 100.0, 1.0e-6)
        verdict(out, r[:contour].length == 4, "ТЗ-1 вершин контура: #{r[:contour].length}")

        # ТЗ-2: квадрат с 16 пилястрами-компонентами вплотную
        x += 30.m
        g = ents.add_group
        g.name = 'ТЗ-2'
        box(g.entities, x, 0, 0, 10.m, 10.m, 3.m, 'стены')
        pil_x = comp_box(model, 'пилястра X', 400.mm, 300.mm, 3.m)
        pil_y = comp_box(model, 'пилястра Y', 300.mm, 400.mm, 3.m)
        [1.5, 3.5, 5.5, 7.5].each do |p|
          place(g.entities, pil_x, x + p.m, -300.mm)
          place(g.entities, pil_x, x + p.m, 10.m)
          place(g.entities, pil_y, x - 300.mm, p.m)
          place(g.entities, pil_y, x + 10.m, p.m)
        end
        r = section(g, opts)
        check(out, 'ТЗ-2 пилястры, площадь', r[:area_m2], 101.92, 1.0e-6)
        verdict(out, r[:contour].length == 68, "ТЗ-2 контур обходит каждую пилястру: вершин #{r[:contour].length} (ожидалось 68)")

        # ТЗ-3: пилястра в 5 мм от стены → в общем контуре
        x += 30.m
        g = ents.add_group
        g.name = 'ТЗ-3'
        box(g.entities, x, 0, 0, 10.m, 10.m, 3.m, 'стены')
        box(g.entities, x + 4.m, -305.mm, 0, 400.mm, 300.mm, 3.m, 'пилястра')
        r = section(g, opts)
        check(out, 'ТЗ-3 пилястра с зазором 5 мм, площадь', r[:area_m2], 100.122, 1.0e-4)
        verdict(out, r[:contour].length == 8 && r[:fragments].empty?,
                "ТЗ-3 пилястра в контуре: вершин #{r[:contour].length}, фрагментов #{r[:fragments].length}")

        # ТЗ-4: две панели с совпадающими торцами
        x += 30.m
        g = ents.add_group
        g.name = 'ТЗ-4'
        box(g.entities, x, 0, 0, 5.m, 10.m, 3.m, 'панель 1')
        box(g.entities, x + 5.m, 0, 0, 5.m, 10.m, 3.m, 'панель 2')
        r = section(g, opts)
        check(out, 'ТЗ-4 стык панелей, площадь', r[:area_m2], 100.0, 1.0e-6)
        verdict(out, r[:contour].length == 4, "ТЗ-4 лишних рёбер на стыке нет: вершин #{r[:contour].length}")

        # ТЗ-6: рез ровно на уровне подоконника → авто-смещение
        x += 30.m
        g = ents.add_group
        g.name = 'ТЗ-6'
        box(g.entities, x, 0, 0, 10.m, 10.m, 3.m, 'объём')
        box(g.entities, x + 2.m, 1.m, 800.mm, 1.m, 300.mm, 200.mm, 'подоконник')
        r = section(g, opts)
        check(out, 'ТЗ-6 высота сдвинута с подоконника', r[:cut_mm], 1002.0, 1.0e-3)

        # ТЗ-7: проём без стекла на высоте реза → перебор высот
        x += 30.m
        g = ents.add_group
        g.name = 'ТЗ-7'
        e = g.entities
        box(e, x, 0, 0, 4.5.m, 300.mm, 3.m, 'стена Ю лев')
        box(e, x + 5.4.m, 0, 0, 4.6.m, 300.mm, 3.m, 'стена Ю прав')
        box(e, x + 4.5.m, 0, 2.1.m, 900.mm, 300.mm, 900.mm, 'перемычка')
        box(e, x, 9.7.m, 0, 10.m, 300.mm, 3.m, 'стена С')
        box(e, x, 0, 0, 300.mm, 10.m, 3.m, 'стена З')
        box(e, x + 9.7.m, 0, 0, 300.mm, 10.m, 3.m, 'стена В')
        r = section(g, opts)
        verdict(out, r[:status] == :ok && r[:cut_mm] > 2000 && (r[:area_m2] - 100.0).abs < 1.0e-6,
                format('ТЗ-7 перебор высот: высота %d мм, площадь %.3f, «%s»',
                       r[:cut_mm].round, r[:area_m2], r[:reason]))

        # ТЗ-8: зеркальный компонент
        x += 30.m
        cube = comp_box(model, 'куб', 10.m, 10.m, 3.m)
        g = ents.add_group
        g.name = 'ТЗ-8'
        inst = g.entities.add_instance(cube, Geom::Transformation.translation([x + 10.m, 0, 0]) *
                                              Geom::Transformation.scaling(-1, 1, 1))
        inst.name = 'зеркальный'
        r = section(g, opts)
        check(out, 'ТЗ-8 зеркальный компонент, площадь', r[:area_m2], 100.0, 1.0e-6)

        # ТЗ-9: этаж внутри здания, открытого на редактирование
        x += 30.m
        building = ents.add_group
        building.name = 'Здание'
        floor = box(building.entities, 0, 0, 0, 10.m, 10.m, 3.m, 'Этаж')
        floor.transform!(Geom::Transformation.translation([5.m, 0, 0]))
        building.transform!(Geom::Transformation.translation([x, 0, 0]))
        if model.respond_to?(:active_path=)
          model.active_path = [building]
          model.selection.clear
          model.selection.add(floor)
          roots = Calc.run('section', 1000, 0, opts)
          model.active_path = nil
          r = roots.first.section
          minx = r[:contour].map(&:first).min
          check(out, 'ТЗ-9 вложенный этаж, мировой X контура, м', minx * 0.0254, (x + 5.m) * 0.0254, 1.0e-6)
          check(out, 'ТЗ-9 вложенный этаж, площадь', r[:area_m2], 100.0, 1.0e-6)
        else
          out << 'SKIP ТЗ-9: нет model.active_path='
        end
        model.selection.clear

        # ТЗ-10: 40 фасадных компонентов с окнами и пилястрами + плита
        x += 30.m
        g = facade(model, ents, x)
        started = Time.now
        r = section(g, opts)
        spent = Time.now - started
        check(out, 'ТЗ-10 фасад 40 панелей, площадь', r[:area_m2], 226.2, 1.0e-4)
        verdict(out, r[:contour].length == 164, "ТЗ-10 контур повторяет пластику: вершин #{r[:contour].length} (ожидалось 164)")
        verdict(out, spent < 5.0, format('ТЗ-10 время %.2f с (нужно < нескольких секунд)', spent))

        # --- прежние сценарии -----------------------------------------------
        x += 40.m
        g = box(ents, x, 0, 0, 20.m, 10.m, 3.5.m, 'T1')
        check(out, 'T1 блок, верхняя грань', top(g), 200.0)

        x += 30.m
        g = ring(ents, x, 0, 0, 20.m, 10.m, x + 7.m, 3.m, 6.m, 4.m, 3.5.m, 'T2')
        check(out, 'T2 двор, верхняя грань', top(g), 176.0)
        check(out, 'T2 двор, сечение по внешнему контуру', section(g, opts)[:area_m2], 200.0)
        check(out, 'T2 двор, сечение с вычетом двора', section(g, opts(subtract_holes: true))[:area_m2], 176.0)

        x += 30.m
        g = frustum(ents, x, 0, 0, 20.m, 10.m, 16.m, 8.m, 3.5.m, 'T3')
        check(out, 'T3 пирамида, верхняя грань', top(g), 128.0)
        check(out, 'T3 пирамида, сечение на 1500', section(g, opts(cut_mm: 1500.0))[:area_m2], 167.18)

        x += 30.m
        g = panels(ents, x, 0, 0, 20.m, 10.m, 200.mm, 30.mm, 3.5.m, 'T4')
        check(out, 'T4 панели с разрывом 30 мм, зазор 50', section(g, opts(gap_mm: 50.0))[:area_m2], 200.0, 1.0e-6)
        r = section(g, opts)
        verdict(out, r[:status] == :problem, "T4 те же панели при зазоре 20 мм — проблема: #{r[:reason]}")

        x += 30.m
        g = box(ents, x, 0, 0, 20.m, 10.m, 3.5.m, 'T6')
        g.transform!(Geom::Transformation.rotation(Geom::Point3d.new(x, 0, 0), Z_AXIS, 30.degrees))
        check(out, 'T6 повёрнутая, верхняя грань', top(g), 200.0)
        check(out, 'T6 повёрнутая, сечение', section(g, opts)[:area_m2], 200.0, 1.0e-6)

        x += 30.m
        g = box(ents, x, 0, 0, 20.m, 10.m, 3.5.m, 'T7')
        g.entities.add_line(Geom::Point3d.new(x, 5.m, 3.5.m), Geom::Point3d.new(x + 20.m, 5.m, 3.5.m))
        check(out, 'T7 разрезанный верх, верхняя грань', top(g), 200.0)

        x += 30.m
        g = ents.add_group
        g.name = 'T8'
        box(g.entities, x, 0, 0, 20.m, 10.m, 3.5.m, 'inner')
        check(out, 'T8 вложенная группа, верхняя грань', top(g), 200.0)

        x += 30.m
        complex = ents.add_group
        complex.name = 'Северный'
        k1 = complex.entities.add_group
        k1.name = 'К1'
        3.times { |i| box(k1.entities, x, 0, i * 3.5.m, 20.m, 10.m, 3.5.m, format('Этаж %02d', i + 1)) }
        k2 = complex.entities.add_group
        k2.name = 'К2'
        2.times { |i| box(k2.entities, x + 25.m, 0, i * 3.5.m, 20.m, 10.m, 3.5.m, format('Этаж %02d', i + 1)) }
        node = Calc.build(complex, Geom::Transformation.new, 2, 'top', 0)
        check(out, 'T9 комплекс, площадь', node.area, 1000.0)
        check(out, 'T9 комплекс, этажей', Calc.leaves([node]).length.to_f, 5.0, 0.0)
        report = Report.build([node])
        keys = report[:tables].keys
        verdict(out, keys == %w[floors blocks complexes], "T9 таблицы: #{keys.join(', ')}")
        row = report[:tables]['complexes']['tsv'].lines[1].to_s.chomp
        verdict(out, row.start_with?("Северный\t1000,00\t5\t2"), "T9 строка комплекса: #{row}")
        node = Calc.build(complex, Geom::Transformation.new, 2, 'section', 0, opts)
        check(out, 'T9 комплекс сечением', node.area, 1000.0, 1.0e-6)
      end

      # --- создание грани в модели (убирает за собой) ----------------------

      def self.builder_tests(model, out)
        model.start_operation('area counter: самопроверка, геометрия', true)
        cube_def = comp_box(model, 'куб ТЗ-8', 10.m, 10.m, 3.m)
        g1 = box(model.entities, OFFSET, 0, 0, 10.m, 10.m, 3.m, 'Этаж-тест')
        g8 = model.entities.add_instance(cube_def, Geom::Transformation.translation([OFFSET + 40.m, 0, 0]) *
                                                    Geom::Transformation.scaling(-1, 1, 1))
        model.commit_operation

        begin
          nodes = [g1, g8].map { |e| Calc.build(e, Geom::Transformation.new, 0, 'section', 0, opts) }
          ok, msg = S::Builder.build(nodes)
          verdict(out, ok, "B1 грань создана: #{msg}")

          groups = section_groups(model)
          faces = groups.flat_map { |grp| grp.entities.grep(Sketchup::Face) }
          verdict(out, groups.length == 2 && faces.length == 2,
                  "B2 по одной грани на этаж: групп #{groups.length}, граней #{faces.length}")
          faces.each_with_index do |f, i|
            check(out, "B3 грань #{i + 1}: площадь в Entity Info", f.area * S::Engine::M2_PER_IN2, 100.0, 1.0e-6)
            verdict(out, f.normal.z > 0, "B4 грань #{i + 1} смотрит вверх (ТЗ-8 — зеркальный компонент)")
          end
          attrs = groups.first.attribute_dictionary('area_counter')
          verdict(out, attrs && attrs['floor_pid'] && attrs['cut_mm'] && attrs['area_m2'] && attrs['date'],
                  "B5 атрибуты: #{attrs ? attrs.keys.join(', ') : 'нет'}")
          verdict(out, groups.first.layer.name == 'AC_Сечения', "B6 тег: #{groups.first.layer.name}")

          # Повторный запуск заменяет прежнее сечение, а не плодит новое
          S::Builder.build(nodes)
          again = section_groups(model)
          verdict(out, again.length == 2, "B7 повторный запуск заменил сечения: групп #{again.length}")

          # Своё сечение не попадает в следующий расчёт
          r = section(g1, opts)
          check(out, 'B8 после выгрузки площадь та же', r[:area_m2], 100.0, 1.0e-6)
        ensure
          model.start_operation('area counter: самопроверка, уборка', true)
          [g1, g8].each { |e| e.erase! unless e.deleted? }
          model.entities.grep(Sketchup::Group).each do |grp|
            grp.erase! if grp.get_attribute('area_counter', 'role')
          end
          model.commit_operation
        end
      end

      def self.section_groups(model)
        found = []
        walk = lambda do |ents|
          ents.grep(Sketchup::Group).each do |grp|
            role = grp.get_attribute('area_counter', 'role')
            next unless role
            role == 'section' ? found << grp : walk.call(grp.entities)
          end
        end
        walk.call(model.entities)
        found
      end

      # --- измерение и отчёт ------------------------------------------------

      def self.section(group, o)
        Calc.reset_cache
        tr = group.is_a?(Sketchup::ComponentInstance) || group.is_a?(Sketchup::Group) ? group.transformation : Geom::Transformation.new
        S::Engine.section(group, tr, o)
      end

      def self.top(group)
        Calc.reset_cache
        Calc.build(group, Geom::Transformation.new, 0, 'top', 0).area
      end

      def self.check(out, title, got, expected, tolerance = 0.01)
        allowed = expected.abs * tolerance + 1.0e-6
        ok = (got.to_f - expected).abs <= allowed
        out << (ok ? 'PASS' : 'FAIL') + " #{title}: #{format('%.4f', got.to_f)} (ожидалось #{format('%.4f', expected)})"
        ok
      end

      def self.verdict(out, ok, text)
        out << (ok ? 'PASS' : 'FAIL') + " #{text}"
        ok
      end

      # --- геометрия ---------------------------------------------------------

      def self.rect(x, y, z, w, d)
        [Geom::Point3d.new(x, y, z), Geom::Point3d.new(x + w, y, z),
         Geom::Point3d.new(x + w, y + d, z), Geom::Point3d.new(x, y + d, z)]
      end

      def self.extrude(face, h)
        face.pushpull(face.normal.z > 0 ? h : -h)
      end

      def self.box(ents, x, y, z, w, d, h, name)
        g = ents.add_group
        g.name = name
        extrude(g.entities.add_face(rect(x, y, z, w, d)), h)
        g
      end

      def self.comp_box(model, name, w, d, h)
        defn = model.definitions.add(name)
        extrude(defn.entities.add_face(rect(0, 0, 0, w, d)), h)
        defn
      end

      def self.place(ents, defn, x, y)
        ents.add_instance(defn, Geom::Transformation.translation([x, y, 0]))
      end

      def self.ring(ents, x, y, z, w, d, hx, hy, hw, hd, h, name)
        g = ents.add_group
        g.name = name
        g.entities.add_face(rect(x, y, z, w, d))
        g.entities.add_face(rect(hx, hy, z, hw, hd)).erase!
        extrude(g.entities.grep(Sketchup::Face).first, h)
        g
      end

      def self.frustum(ents, x, y, z, w, d, w2, d2, h, name)
        g = ents.add_group
        g.name = name
        bottom = rect(x, y, z, w, d)
        top    = rect(x + (w - w2) / 2.0, y + (d - d2) / 2.0, z + h, w2, d2)
        g.entities.add_face(bottom)
        g.entities.add_face(top)
        4.times do |i|
          g.entities.add_face([bottom[i], bottom[(i + 1) % 4], top[(i + 1) % 4], top[i]])
        end
        g
      end

      def self.panels(ents, x, y, z, w, d, thick, gap, h, name)
        g = ents.add_group
        g.name = name
        e = g.entities
        box(e, x, y, z, w, thick, h, 'S')
        box(e, x, y + d - thick, z, w, thick, h, 'N')
        box(e, x, y + thick + gap, z, thick, d - 2 * thick - 2 * gap, h, 'W')
        box(e, x + w - thick, y + thick + gap, z, thick, d - 2 * thick - 2 * gap, h, 'E')
        g
      end

      # Фасадная панель 1,5 × 0,25 × 3 м: окно 0,9 × 1,2 со стеклом вровень
      # с наружной гранью, пилястра 0,2 × 0,15 наружу. Наружная грань — y = 0.
      def self.facade_panel(model)
        defn = model.definitions.add('Фасадная панель')
        e = defn.entities
        outer = [Geom::Point3d.new(0, 0, 0), Geom::Point3d.new(1.5.m, 0, 0),
                 Geom::Point3d.new(1.5.m, 0, 3.m), Geom::Point3d.new(0, 0, 3.m)]
        win = [Geom::Point3d.new(0.3.m, 0, 0.9.m), Geom::Point3d.new(1.2.m, 0, 0.9.m),
               Geom::Point3d.new(1.2.m, 0, 2.1.m), Geom::Point3d.new(0.3.m, 0, 2.1.m)]
        face = e.add_face(outer)
        e.add_face(win).erase!
        face.pushpull(face.normal.y > 0 ? 250.mm : -250.mm)

        glass = e.add_group
        glass.name = 'стекло'
        gf = glass.entities.add_face([Geom::Point3d.new(0.3.m, 0, 0.9.m), Geom::Point3d.new(1.2.m, 0, 0.9.m),
                                      Geom::Point3d.new(1.2.m, 0, 2.1.m), Geom::Point3d.new(0.3.m, 0, 2.1.m)])
        gf.pushpull(gf.normal.y > 0 ? 20.mm : -20.mm)

        pil = e.add_group
        pil.name = 'пилястра'
        extrude(pil.entities.add_face(rect(0.65.m, -150.mm, 0, 200.mm, 150.mm)), 3.m)
        defn
      end

      def self.facade(model, ents, x)
        g = ents.add_group
        g.name = 'ТЗ-10'
        panel = facade_panel(model)
        side = 15.m
        step = 1.5.m
        rot = ->(deg) { Geom::Transformation.rotation(ORIGIN, Z_AXIS, deg.degrees) }
        mv  = ->(px, py) { Geom::Transformation.translation([x + px, py, 0]) }
        10.times do |i|
          g.entities.add_instance(panel, mv.call(i * step, 0))
          g.entities.add_instance(panel, mv.call(side, i * step) * rot.call(90))
          g.entities.add_instance(panel, mv.call(side - i * step, side) * rot.call(180))
          g.entities.add_instance(panel, mv.call(0, side - i * step) * rot.call(270))
        end
        box(g.entities, x, 0, 0, side, side, 200.mm, 'плита')
        g
      end

    end # module SelfTest
  end # module AreaCounter
end # module BACommunity
