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

    HERE = File.dirname(__FILE__).freeze

    require File.join(HERE, 'calc.rb')
    require File.join(HERE, 'report.rb')
    require File.join(HERE, 'highlight.rb')
    require File.join(HERE, 'panel.rb')
    require File.join(HERE, 'toolbar.rb')

    unless file_loaded?(__FILE__)
      self.create_menu
      self.create_toolbar

      file_loaded(__FILE__)
    end

  end # module AreaCounter
end # module BACommunity
