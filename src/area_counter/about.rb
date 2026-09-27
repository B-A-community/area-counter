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
require 'json'

module BACommunity
  module AreaCounter

    # Окно «О плагине»: авторы, версия, ссылка на репозиторий — как в RALNCS.
    module About

      REPO_URL = 'https://github.com/B-A-community/area-counter'.freeze

      def self.show
        @dialog.close if @dialog && @dialog.visible?
        @dialog = UI::HtmlDialog.new(
          dialog_title:    AreaCounter.t(:title_about),
          preferences_key: 'BACommunity_AreaCounter_About',
          width:           440,
          height:          350,
          resizable:       false,
          style:           UI::HtmlDialog::STYLE_DIALOG
        )
        # preferences_key запоминает и размер: окно без ресайза держим своим
        @dialog.set_size(440, 350)
        @dialog.set_file(File.join(File.dirname(__FILE__), 'html', 'about.html'))
        @dialog.add_action_callback('ready') do |_ctx|
          @dialog.execute_script("init(#{{ version: VERSION }.to_json})")
        end
        # Открываем только свой репозиторий, что бы ни прислала страница
        @dialog.add_action_callback('open_url') { |_ctx, url| UI.openURL(url) if url == REPO_URL }
        @dialog.add_action_callback('close') { |_ctx| @dialog.close }
        @dialog.show
        @dialog
      end

    end # module About
  end # module AreaCounter
end # module BACommunity
