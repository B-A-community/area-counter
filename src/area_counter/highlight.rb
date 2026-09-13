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

    # Подсветка того, что попало в расчёт. Ничего в модели не меняется,
    # рисование живёт только во вьюпорте.
    #
    # Габариты этажей — тонкой линией: посчитанные мятным, проблемные янтарным.
    # Контуры сечения — толстой: замкнутые мятным, разошедшиеся куски янтарным.
    # По ним видно, где именно сечение не сошлось и что в него не попало.
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
            problem = item[:status] == :problem

            if item[:bbox]
              view.drawing_color = problem ? PROBLEM_COLOR : OK_COLOR
              view.line_width = 1
              view.draw(GL_LINES, box_lines(item[:bbox]))
            end

            view.line_width = 3
            (item[:loops] || []).each do |ring|
              next if ring.length < 2
              view.drawing_color = OK_COLOR
              view.draw(GL_LINE_LOOP, ring)
            end
            (item[:opens] || []).each do |chain|
              next if chain.length < 2
              view.drawing_color = PROBLEM_COLOR
              view.draw(GL_LINE_STRIP, chain)
            end

            outline = item[:envelope] || []
            if outline.length >= 2
              view.drawing_color = OK_COLOR
              view.line_width = 2
              view.draw(GL_LINES, outline)
            end
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
          { bbox: node.bbox, status: node.status,
            loops: node.loops || [], opens: node.opens || [],
            envelope: node.envelope || [] }
        end
        return false if items.empty?
        Sketchup.active_model.select_tool(BoxTool.new(items))
        true
      end

      def self.stop
        Sketchup.active_model.select_tool(nil)
      end

      # Камеру наводим по мировому габариту, а не через view.zoom(entity):
      # для вложенного объекта тот берёт локальные координаты и улетает
      # к началу осей. Направление взгляда сохраняем, меняем только дистанцию.
      def self.zoom_to(node)
        return false if node.nil? || node.bbox.nil?
        model = Sketchup.active_model
        view  = model.active_view

        if node.entity && !node.entity.deleted?
          model.selection.clear
          model.selection.add(node.entity)
        end

        low, high = node.bbox
        box = Geom::BoundingBox.new
        box.add(low)
        box.add(high)
        center = box.center
        radius = [box.diagonal / 2.0, 1.0.m].max

        camera = view.camera
        dir    = camera.direction
        up     = camera.up

        if camera.perspective?
          fov  = [camera.fov.to_f, 10.0].max
          dist = radius / Math.sin(fov * Math::PI / 360.0) * 1.2
          eye  = center.offset(dir.reverse, dist)
          camera.set(eye, center, up)
        else
          eye = center.offset(dir.reverse, radius * 3.0)
          camera.set(eye, center, up)
          camera.height = radius * 2.4
        end

        view.camera = camera
        view.invalidate
        true
      end

    end # module Highlight
  end # module AreaCounter
end # module BACommunity
