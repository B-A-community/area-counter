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

# Самопроверка area counter на эталонных фигурах с известной площадью.
#
# Запуск из Ruby Console SketchUp при загруженном плагине:
#   load 'C:/путь/к/репозиторию/tools/selftest.rb'
#   BACommunity::AreaCounter::SelfTest.run
#
# Фигуры строятся в 300 м от начала координат внутри одной операции,
# которая в конце откатывается — модель остаётся ровно такой, какой была.

module BACommunity
  module AreaCounter
    module SelfTest

      OFFSET = 300.m
      LEVEL  = 1500.0.mm

      def self.run
        model = Sketchup.active_model
        model.start_operation('area counter: самопроверка', true)
        results = []
        begin
          root = model.entities.add_group
          root.name = 'ac_selftest'
          cases(root.entities, results)
        rescue StandardError => e
          results << "CRASH #{e.class}: #{e.message} @ #{e.backtrace.first(3).join(' | ')}"
        ensure
          model.abort_operation
        end
        summary = results.join("\n")
        puts summary
        summary
      end

      # --- сценарии ----------------------------------------------------------

      def self.cases(ents, out)
        x = OFFSET

        # T1. Сплошной параллелепипед 20×10×3,5 м — базовый случай
        g = box(ents, x, 0, 0, 20.m, 10.m, 3.5.m, 'T1')
        check(out, 'T1 сплошной, верхняя грань', area(g, 'top'), 200.0)
        check(out, 'T1 сплошной, сечение',       area(g, 'section'), 200.0)

        # T2. Кольцо с двором 6×4 м — двор должен вычесться (В4)
        x += 30.m
        g = ring(ents, x, 0, 0, 20.m, 10.m, x + 7.m, 3.m, 6.m, 4.m, 3.5.m, 'T2')
        check(out, 'T2 двор, верхняя грань', area(g, 'top'), 176.0)
        check(out, 'T2 двор, сечение',       area(g, 'section'), 176.0)

        # T3. Усечённая пирамида: низ 20×10, верх 16×8, высота 3,5 м.
        # Верхняя грань даёт 128, а на отметке 1,5 м честно 18,29×9,14 = 167,2
        x += 30.m
        g = frustum(ents, x, 0, 0, 20.m, 10.m, 16.m, 8.m, 3.5.m, 'T3')
        check(out, 'T3 пирамида, верхняя грань', area(g, 'top'), 128.0)
        check(out, 'T3 пирамида, сечение',       area(g, 'section'), 167.18)

        # T4. Здание из четырёх панелей 200 мм с разрывами 30 мм по углам:
        # замкнутого контура нет, работает огибающая. Ожидаем габарит 20×10.
        x += 30.m
        g = panels(ents, x, 0, 0, 20.m, 10.m, 200.mm, 30.mm, 3.5.m, 'T4')
        t0 = Time.now
        a  = area(g, 'section')
        dt = Time.now - t0
        check(out, 'T4 панели с разрывом 30 мм, сечение', a, 200.0, 0.03)
        out << format('     огибающая за %.2f с', dt)
        node = build(g, 0, 'section')
        out << "     причина: #{node.reason.inspect}, статус #{node.status}"

        # T5. Разрыв 120 мм — больше допуска, огибающая не должна сомкнуть его
        # в одну стену... но и не должна дать ноль: контур подсвечивается.
        x += 30.m
        g = panels(ents, x, 0, 0, 20.m, 10.m, 200.mm, 120.mm, 3.5.m, 'T5')
        node = build(g, 0, 'section')
        out << "T5 панели с разрывом 120 мм: #{fmt(node.area)} м², статус #{node.status} (справочно)"

        # T6. Повёрнутая на 30° группа — раньше давала ноль по верхней грани
        x += 30.m
        g = box(ents, x, 0, 0, 20.m, 10.m, 3.5.m, 'T6')
        g.transform!(Geom::Transformation.rotation(Geom::Point3d.new(x, 0, 0), Z_AXIS, 30.degrees))
        check(out, 'T6 повёрнутая, верхняя грань', area(g, 'top'), 200.0)
        check(out, 'T6 повёрнутая, сечение',       area(g, 'section'), 200.0)

        # T7. Верхняя грань разрезана надвое — раньше считался один кусок
        x += 30.m
        g = box(ents, x, 0, 0, 20.m, 10.m, 3.5.m, 'T7')
        g.entities.add_line(Geom::Point3d.new(x, 5.m, 3.5.m), Geom::Point3d.new(x + 20.m, 5.m, 3.5.m))
        check(out, 'T7 разрезанный верх, верхняя грань', area(g, 'top'), 200.0)

        # T8. Этаж с вложенной группой внутри — раньше давал ноль
        x += 30.m
        g = ents.add_group
        g.name = 'T8'
        box(g.entities, x, 0, 0, 20.m, 10.m, 3.5.m, 'inner')
        check(out, 'T8 вложенная группа, верхняя грань', area(g, 'top'), 200.0)

        # T9. Иерархия: комплекс → два корпуса → этажи
        x += 30.m
        complex = ents.add_group
        complex.name = 'Северный'
        k1 = complex.entities.add_group
        k1.name = 'К1'
        3.times { |i| box(k1.entities, x, 0, i * 3.5.m, 20.m, 10.m, 3.5.m, format('Этаж %02d', i + 1)) }
        k2 = complex.entities.add_group
        k2.name = 'К2'
        2.times { |i| box(k2.entities, x + 25.m, 0, i * 3.5.m, 20.m, 10.m, 3.5.m, format('Этаж %02d', i + 1)) }

        node = build(complex, 2, 'top')
        check(out, 'T9 комплекс, глубина 2, площадь', node.area, 1000.0)
        check(out, 'T9 комплекс, этажей', Calc.leaves([node]).length.to_f, 5.0, 0.0)
        node1 = build(k1, 1, 'top')
        check(out, 'T9 корпус К1, глубина 1', node1.area, 600.0)
        deep = build(complex, 5, 'top')
        check(out, 'T9 глубина больше дерева — не ломается', deep.area, 1000.0)

        report = Report.build([node])
        keys   = report[:tables].keys
        out << (keys == %w[floors blocks complexes] ? 'PASS' : 'FAIL') + " T9 таблицы: #{keys.join(', ')}"
        head = report[:tables]['floors']['tsv'].lines.first.chomp
        out << (head.start_with?("Комплекс\tКорпус\tЭтаж") ? 'PASS' : 'FAIL') + " T9 заголовок этажей: #{head}"
        cx = report[:tables]['complexes']
        row = cx['tsv'].lines[1].to_s.chomp
        out << (row.start_with?("Северный\t1000,00\t5\t2") ? 'PASS' : 'FAIL') + " T9 строка комплекса: #{row}"
        bl = report[:tables]['blocks']['tsv'].lines[1].to_s.chomp
        out << (bl.start_with?("Северный\tК1\t600,00\t3\t5\t1000,00") ? 'PASS' : 'FAIL') + " T9 строка корпуса: #{bl}"

        # T10. Неровное дерево: второй корпус — сплошной блок без этажей
        x += 60.m
        complex = ents.add_group
        complex.name = 'Южный'
        k1 = complex.entities.add_group
        k1.name = 'К1'
        2.times { |i| box(k1.entities, x, 0, i * 3.5.m, 20.m, 10.m, 3.5.m, format('Этаж %02d', i + 1)) }
        box(complex.entities, x + 25.m, 0, 0, 20.m, 10.m, 3.5.m, 'К2 блоком')
        node = build(complex, 2, 'top')
        check(out, 'T10 неровное дерево, площадь', node.area, 600.0)
        report = Report.build([node])
        rows = report[:tables]['floors']['tsv'].lines.length - 1
        out << (rows == 3 ? 'PASS' : 'FAIL') + " T10 строк этажей: #{rows} (ожидалось 3)"
        last = report[:tables]['floors']['tsv'].lines.last.chomp
        out << (last.start_with?("Южный\t\tК2 блоком") ? 'PASS' : 'FAIL') + " T10 блок без корпуса: #{last}"
      end

      # --- измерение ---------------------------------------------------------

      def self.build(group, depth, method_key)
        Calc.reset_cache
        Calc.build(group, Geom::Transformation.new, depth, method_key, LEVEL)
      end

      def self.area(group, method_key)
        build(group, 0, method_key).area
      end

      def self.check(out, title, got, expected, tolerance = 0.01)
        allowed = expected.abs * tolerance + 0.05
        ok = (got - expected).abs <= allowed
        out << (ok ? 'PASS' : 'FAIL') + " #{title}: #{fmt(got)} (ожидалось #{fmt(expected)})"
        ok
      end

      def self.fmt(value)
        format('%.2f', value.to_f)
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

      # Четыре стены-панели с зазором gap по углам (южная и северная — во всю
      # длину, западная и восточная — между ними с отступом).
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

    end # module SelfTest
  end # module AreaCounter
end # module BACommunity
