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

# area counter — автоматизация математических расчётов внутри SketchUp.
# Точка входа: регистрирует расширение, реальный код грузится из area_counter/main.rb.

require 'sketchup.rb'
require 'extensions.rb'

module BACommunity
  module AreaCounter

    EXTENSION_NAME = 'area counter'.freeze
    VERSION        = '0.2'.freeze

    loader = SketchupExtension.new(EXTENSION_NAME, File.join('area_counter', 'main.rb'))
    loader.copyright   = 'Copyright 2026 B&A community, Apache License 2.0'
    loader.creator     = 'B&A community — maksarsanjeev, Royalb21'
    loader.version     = VERSION
    loader.description = 'Математические расчёты по модели: площади, объёмы, длины, спецификации.'
    Sketchup.register_extension(loader, true)

  end # module AreaCounter
end # module BACommunity
