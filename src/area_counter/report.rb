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

    # Дерево для окна и таблицы для буфера.
    #
    # Уровень узла — высота его поддерева: лист (0) — этаж, над ним (1) — корпус,
    # над корпусом (2) — комплекс. Так смешанное выделение не съезжает:
    # у отдельно выделенного этажа просто пустые колонки старших уровней.
    #
    # Таблиц три — по этажам, по корпусам, по комплексам. Все длинные (строка на
    # объект), числа с запятой, ячейки через табуляцию: в буфере запятая в числе
    # ни с чем не конфликтует, в отличие от CSV.
    module Report

      NO_NAME = 'Без имени'.freeze

      LEVEL = { 0 => 'Этаж',  1 => 'Корпус',  2 => 'Комплекс'  }.freeze
      GEN   = { 0 => 'этажа', 1 => 'корпуса', 2 => 'комплекса' }.freeze  # площадь чего
      LOC   = { 0 => 'этаже', 1 => 'корпусе', 2 => 'комплексе' }.freeze  # этажей в чём
      KEY   = { 0 => 'floors', 1 => 'blocks', 2 => 'complexes' }.freeze
      PLURAL = { 0 => 'Этажи', 1 => 'Корпуса', 2 => 'Комплексы' }.freeze

      Entry = Struct.new(:node, :id, :height, :parent, :floors)

      def self.level_name(h) LEVEL[h] || "Уровень #{h}"  end
      def self.gen(h)        GEN[h]   || "уровня #{h}"   end
      def self.loc(h)        LOC[h]   || "уровне #{h}"   end
      def self.key(h)        KEY[h]   || "level#{h}"     end
      def self.plural(h)     PLURAL[h] || "Уровень #{h}" end

      def self.display_name(node)
        name = node.name.to_s.strip
        name.empty? ? NO_NAME : name
      end

      def self.number(value)
        format('%.2f', value.to_f).tr('.', ',')
      end

      # --- сборка ------------------------------------------------------------

      def self.build(roots)
        @index   = {}
        @entries = []
        annotate(roots, nil)

        max_h  = @entries.map(&:height).max || 0
        leaves = @entries.select { |e| e.height.zero? }

        tables = {}
        0.upto(max_h) do |h|
          tables[key(h)] = table_for(h, max_h)
        end

        {
          tree:       roots.map { |root| tree_json(root) },
          entries:    @entries,
          max_height: max_h,
          tables:     tables,
          total_area: roots.inject(0.0) { |sum, root| sum + root.area.to_f },
          floors:     leaves.length,
          problems:   leaves.count { |e| e.node.status == :problem }
        }
      end

      def self.annotate(nodes, parent)
        nodes.each do |node|
          entry = Entry.new(node, @entries.length, 0, parent, 0)
          @entries << entry
          if node.children.empty?
            entry.height = 0
            entry.floors = 1
          else
            annotate(node.children, entry)
            kids = node.children.map { |child| @index[child.object_id] }
            entry.height = kids.map(&:height).max + 1
            entry.floors = kids.inject(0) { |sum, kid| sum + kid.floors }
          end
          @index[node.object_id] = entry
        end
      end

      def self.entry_of(node)
        @index[node.object_id]
      end

      def self.tree_json(node)
        entry = entry_of(node)
        {
          'id'       => entry.id,
          'name'     => display_name(node),
          'height'   => entry.height,
          'level'    => level_name(entry.height),
          'area'     => number(node.area),
          'status'   => node.status.to_s,
          'reason'   => node.reason,
          'floors'   => entry.floors,
          'children' => node.children.map { |child| tree_json(child) }
        }
      end

      # --- таблицы -----------------------------------------------------------

      def self.table_for(h, max_h)
        columns = max_h.downto(h).map { |lvl| level_name(lvl) }
        columns << "Площадь #{gen(h)}, м²"
        columns << "Этажей в #{loc(h)}"   if h >= 1
        columns << "Корпусов в #{loc(h)}" if h >= 2
        (h + 1).upto(max_h) do |a|
          columns << "Этажей в #{loc(a)}"
          columns << "Площадь #{gen(a)}, м²"
        end

        rows = @entries.select { |e| e.height == h }.map { |e| cells_for(e, h, max_h) }

        # cells уходят в окно: оттуда таблица копируется в буфер сразу в двух
        # форматах (TSV + HTML). tsv остаётся для самопроверки.
        { 'label' => plural(h), 'columns' => columns, 'cells' => rows,
          'rows' => rows.length, 'tsv' => tsv(columns, rows) }
      end

      def self.cells_for(entry, h, max_h)
        # Предки по их собственной высоте: у неровного дерева между этажом
        # и комплексом может не оказаться корпуса — тогда колонка пустая.
        ancestors = {}
        cursor = entry
        while cursor
          ancestors[cursor.height] ||= cursor
          cursor = cursor.parent
        end

        cells = max_h.downto(h).map do |lvl|
          ancestors[lvl] ? display_name(ancestors[lvl].node) : ''
        end
        cells << number(entry.node.area)
        cells << entry.floors.to_s if h >= 1
        cells << entry.node.children.length.to_s if h >= 2
        (h + 1).upto(max_h) do |a|
          if ancestors[a]
            cells << ancestors[a].floors.to_s
            cells << number(ancestors[a].node.area)
          else
            cells << ''
            cells << ''
          end
        end
        cells
      end

      def self.tsv(columns, rows)
        lines = [columns.join("\t")]
        rows.each { |cells| lines << cells.join("\t") }
        lines.join("\n")
      end

    end # module Report
  end # module AreaCounter
end # module BACommunity
