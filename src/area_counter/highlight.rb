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

    # Подсветка того, что попало в расчёт: посчитанные этажи обводятся
    # мятным, проблемные — янтарным. Ничего в модели не меняется,
    # рисование живёт только во вьюпорте.
    module Highlight

      OK_COLOR      = Sketchup::Color.new(168, 222, 196)
      PROBLEM_COLOR = Sketchup::Color.new(226, 168, 96)

      class BoxTool

        def initialize(items)
          @items = items
        end

        def activate
          Sketchup.status_text = 'Подсветка area counter. Esc — выйти.'
          Sketchup.active_model.active_view.invalidate
        end

        def deactivate(view)
          Sketchup.status_text = ''
          view.invalidate
        end

        def resume(view)
          view.invalidate
        end

        def onCancel(_reason, _view)
          Sketchup.active_model.select_tool(nil)
        end

        def draw(view)
          @items.each do |item|
            next if item[:bbox].nil?
            view.drawing_color = item[:status] == :problem ? PROBLEM_COLOR : OK_COLOR
            view.line_width = item[:status] == :problem ? 4 : 2
            view.draw(GL_LINES, box_lines(item[:bbox]))
          end
        end

        private

        def box_lines(bbox)
          low, high = bbox
          x0 = low.x;  y0 = low.y;  z0 = low.z
          x1 = high.x; y1 = high.y; z1 = high.z

          corners = [
            Geom::Point3d.new(x0, y0, z0), Geom::Point3d.new(x1, y0, z0),
            Geom::Point3d.new(x1, y1, z0), Geom::Point3d.new(x0, y1, z0),
            Geom::Point3d.new(x0, y0, z1), Geom::Point3d.new(x1, y0, z1),
            Geom::Point3d.new(x1, y1, z1), Geom::Point3d.new(x0, y1, z1)
          ]

          pairs = [
            [0, 1], [1, 2], [2, 3], [3, 0],
            [4, 5], [5, 6], [6, 7], [7, 4],
            [0, 4], [1, 5], [2, 6], [3, 7]
          ]

          lines = []
          pairs.each do |(a, b)|
            lines << corners[a]
            lines << corners[b]
          end
          lines
        end

      end # class BoxTool

      def self.show(nodes)
        items = Calc.leaves(nodes).map do |node|
          { bbox: node.bbox, status: node.status }
        end
        return false if items.empty?
        Sketchup.active_model.select_tool(BoxTool.new(items))
        true
      end

      def self.stop
        Sketchup.active_model.select_tool(nil)
      end

      def self.zoom_to(node)
        return false if node.nil? || node.entity.nil? || node.entity.deleted?
        model = Sketchup.active_model
        model.selection.clear
        model.selection.add(node.entity)
        model.active_view.zoom(node.entity)
        true
      end

    end # module Highlight
  end # module AreaCounter
end # module BACommunity
