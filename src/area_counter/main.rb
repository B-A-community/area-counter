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
require File.join(File.dirname(__FILE__), 'toolbar.rb')

# Main code
module BACommunity
  module AreaCounter

    def self.my_method
      model = Sketchup.active_model
      selection = model.selection
      total_area_sqm = 0.0

      processed_count = 0

      selection.each do |entity|
        next unless entity.is_a?(Sketchup::Group) || entity.is_a?(Sketchup::ComponentInstance)
        processed_count += 1

        entities = entity.is_a?(Sketchup::Group) ? entity.entities : entity.definition.entities

        top_face = nil
        top_z = -Float::INFINITY

        entities.grep(Sketchup::Face).each do |face|
          normal = face.normal
          next unless normal.parallel?(Z_AXIS)

          center = face.bounds.center
          world_center = center.transform(entity.transformation)

          if world_center.z > top_z
            top_z = world_center.z
            top_face = face
          end
        end

        if top_face
          area_sq_in = top_face.area(entity.transformation)
          area_sqm = area_sq_in * 0.00064516 # 1 кв. дюйм = 0.00064516 кв. м
          total_area_sqm += area_sqm
        end
      end

      if processed_count == 0
        UI.messagebox('Пожалуйста, выберите хотя бы одну группу или компонент.')
      else
        UI.messagebox(
          "Обработано объектов: #{processed_count}\n" \
          "Суммарная площадь верхних граней: #{'%.3f' % total_area_sqm} кв. метров"
        )
      end
    end

    # Create menu items and toolbar (once when loading)
    unless file_loaded?(__FILE__)
      self.create_menu
      self.create_toolbar

      file_loaded(__FILE__)
    end
  end # module AreaCounter
end # module BACommunity
