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

    # Длинная таблица: строка на этаж (В10).
    # Числа с запятой (В11), ячейки разделяются табуляцией — поэтому
    # в буфере запятая в числе ни с чем не конфликтует, в отличие от CSV.
    module Report

      NO_NAME = 'Без имени'.freeze

      def self.build(roots)
        rows = []
        roots.each { |root| walk(root, [], nil, rows) }

        depth   = rows.map { |row| row[:path].length }.max || 1
        columns = level_names(depth) + ['Площадь этажа, м²']
        columns += ['Этажей в корпусе', 'Площадь корпуса, м²'] if depth >= 2

        cells = rows.map { |row| cells_for(row, depth) }

        {
          columns: columns,
          rows: rows,
          cells: cells,
          total_area: rows.inject(0.0) { |sum, row| sum + row[:area].to_f },
          floors: rows.length,
          problems: rows.count { |row| row[:status] == :problem }
        }
      end

      def self.walk(node, path, parent, rows)
        here = path + [node.name.to_s.strip.empty? ? NO_NAME : node.name.strip]
        if node.children.empty?
          rows << {
            path: here,
            area: node.area.to_f,
            status: node.status,
            reason: node.reason,
            parent: parent,
            node: node
          }
        else
          node.children.each { |child| walk(child, here, node, rows) }
        end
      end

      def self.level_names(depth)
        case depth
        when 1 then ['Этаж']
        when 2 then ['Корпус', 'Этаж']
        when 3 then ['Квартал', 'Корпус', 'Этаж']
        else
          (1..(depth - 1)).map { |i| "Уровень #{i}" } + ['Этаж']
        end
      end

      # Пути разной длины выравниваем вправо, чтобы «Этаж» всегда был
      # последней колонкой уровней — иначе смешанное выделение съедет.
      def self.cells_for(row, depth)
        path = row[:path]
        path = Array.new(depth - path.length, '') + path if path.length < depth

        cells = path.dup
        cells << number(row[:area])

        if depth >= 2
          parent = row[:parent]
          if parent
            cells << Calc.leaves([parent]).length.to_s
            cells << number(parent.area)
          else
            cells << ''
            cells << ''
          end
        end
        cells
      end

      def self.number(value)
        format('%.2f', value.to_f).tr('.', ',')
      end

      def self.tsv(report)
        lines = [report[:columns].join("\t")]
        report[:cells].each { |cells| lines << cells.join("\t") }
        lines.join("\n")
      end

    end # module Report
  end # module AreaCounter
end # module BACommunity
