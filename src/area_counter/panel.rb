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

    # Окно плагина. Считает по нажатию, показывает таблицу и итоги,
    # отдаёт таблицу в буфер обмена и включает подсветку.
    module Panel

      HTML_FILE = File.join(File.dirname(__FILE__), 'html', 'panel.html').freeze

      # Строк в списке. Таблица в буфер уходит целиком, а вот рисовать
      # тысячи строк в окне бессмысленно и медленно.
      MAX_ROWS = 400

      @dialog = nil
      @roots  = nil
      @report = nil
      @leaves = []
      @note   = nil
      @method = 'top'
      @offset = 1500
      @depth  = 1

      # Метод называется show, а не open: open — приватный метод Kernel,
      # перекрывать его у модуля не стоит.
      def self.show
        if @dialog && @dialog.visible?
          @dialog.bring_to_front
          return @dialog
        end

        @dialog = UI::HtmlDialog.new(
          dialog_title:    'area counter',
          preferences_key: 'BACommunity_AreaCounter_Panel',
          scrollable:      false,
          resizable:       true,
          width:           940,
          height:          560,
          min_width:       720,
          min_height:      420,
          style:           UI::HtmlDialog::STYLE_DIALOG
        )
        @dialog.set_file(HTML_FILE)
        attach_callbacks(@dialog)
        @dialog.show
        @dialog
      end

      def self.attach_callbacks(dialog)
        dialog.add_action_callback('ready') { |_ctx| push }
        dialog.add_action_callback('recalc') do |_ctx, method_key, offset_mm, depth|
          @method = method_key.to_s
          @offset = offset_mm.to_f
          @depth  = depth.to_i
          recalc
        end
        dialog.add_action_callback('highlight') { |_ctx| do_highlight }
        dialog.add_action_callback('stop_highlight') { |_ctx| Highlight.stop; push }
        dialog.add_action_callback('zoom') do |_ctx, index|
          node = @leaves[index.to_i]
          Highlight.zoom_to(node)
        end
        dialog.add_action_callback('copied') do |_ctx, ok|
          note = ok ? 'Таблица скопирована — вставляйте в Google Sheets или Excel.'
                    : 'Скопировать не удалось. Выделите таблицу и скопируйте вручную.'
          say(note)
        end
      end

      # --- расчёт ------------------------------------------------------------

      def self.recalc
        started = Time.now
        @roots  = Calc.run(@method, @offset, @depth)

        if @roots.nil?
          @report = nil
          @leaves = []
          say('Выделите группу или компонент и нажмите «Посчитать».')
          push
          return
        end

        @report = Report.build(@roots)
        @leaves = @report[:rows].map { |row| row[:node] }

        spent = Time.now - started
        say(format('Посчитано %d за %.1f с.', @report[:floors], spent))
        push
      end

      def self.do_highlight
        if @roots.nil?
          say('Сначала посчитайте — подсвечивать пока нечего.')
          push
          return
        end
        Highlight.show(@roots)
        say('Подсветка включена. Esc во вьюпорте — выключить.')
        push
      end

      def self.say(text)
        @note = text
      end

      # --- отправка в окно ---------------------------------------------------

      def self.push
        return if @dialog.nil? || !@dialog.visible?
        @dialog.execute_script("window.acRender(#{payload.to_json});")
      end

      def self.payload
        base = {
          'method'    => @method,
          'offset'    => @offset.to_i,
          'depth'     => @depth,
          'note'      => @note,
          'columns'   => [],
          'rows'      => [],
          'hidden'    => 0,
          'totals'    => { 'area' => '0,00', 'floors' => 0, 'problems' => 0 },
          'tsv'       => ''
        }
        return base if @report.nil?

        rows = []
        @report[:rows].first(MAX_ROWS).each_with_index do |row, index|
          rows << {
            'index'  => index,
            'cells'  => @report[:cells][index],
            'name'   => row[:path].last,
            'parent' => row[:path].length > 1 ? row[:path][-2] : '',
            'area'   => Report.number(row[:area]),
            'status' => row[:status].to_s,
            'reason' => row[:reason]
          }
        end

        base['columns'] = @report[:columns]
        base['rows']    = rows
        base['hidden']  = [@report[:rows].length - rows.length, 0].max
        base['totals']  = {
          'area'     => Report.number(@report[:total_area]),
          'floors'   => @report[:floors],
          'problems' => @report[:problems]
        }
        base['tsv'] = Report.tsv(@report)
        base
      end

      # Кнопки панели инструментов заходят сюда.
      def self.count_now
        show
        recalc
      end

      def self.copy_now
        show
        recalc if @report.nil?
        push
        @dialog.execute_script('window.acCopy && window.acCopy();')
      end

      def self.highlight_now
        show
        recalc if @roots.nil?
        do_highlight
      end

    end # module Panel
  end # module AreaCounter
end # module BACommunity
