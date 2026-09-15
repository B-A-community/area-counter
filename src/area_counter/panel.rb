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

    # Окно плагина по дизайн-коду B&A: данные уходят в html после колбэка
    # ready через execute_script("init(json)"), настройки живут в реестре
    # компактной строкой без кавычек — JSON там ломается.
    module Panel

      HTML_FILE     = File.join(File.dirname(__FILE__), 'html', 'panel.html').freeze
      PREFS_SECTION = 'BACommunity_AreaCounter'.freeze

      @dialog = nil
      @roots  = nil
      @report = nil
      @toast  = nil
      @spent  = nil
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

        load_prefs

        @dialog = UI::HtmlDialog.new(
          dialog_title:    'area counter',
          preferences_key: 'BACommunity_AreaCounter_Panel',
          scrollable:      false,
          resizable:       true,
          width:           900,
          height:          560,
          min_width:       640,
          min_height:      380,
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
        dialog.add_action_callback('zoom') do |_ctx, id|
          entry = @report && @report[:entries][id.to_i]
          Highlight.zoom_to(entry.node) if entry
        end
        dialog.add_action_callback('save_prefs') do |_ctx, spec|
          Sketchup.write_default(PREFS_SECTION, 'prefs', spec.to_s)
          apply_prefs(spec.to_s)
        end
      end

      # --- настройки ---------------------------------------------------------

      def self.load_prefs
        apply_prefs(Sketchup.read_default(PREFS_SECTION, 'prefs', nil).to_s)
      end

      # Строка вида "depth:1,method:section,offset:1500,copy:blocks"
      def self.apply_prefs(spec)
        spec.split(',').each do |pair|
          key, value = pair.split(':', 2)
          case key
          when 'depth'  then @depth  = value.to_i
          when 'method' then @method = value.to_s
          when 'offset' then @offset = value.to_f
          end
        end
      end

      # --- расчёт ------------------------------------------------------------

      def self.recalc
        started = Time.now
        @roots  = Calc.run(@method, @offset, @depth)

        if @roots.nil?
          @report = nil
          @spent  = nil
          say('Ничего не выделено. Выделите корпус, комплекс или этажи.')
          push
          return
        end

        @report = Report.build(@roots)
        @spent  = format('%.1f', Time.now - started)
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

      # Одноразовое сообщение: окно покажет его тостом
      def self.say(text)
        @toast = text
      end

      # --- отправка в окно ---------------------------------------------------

      def self.push
        return if @dialog.nil? || !@dialog.visible?
        @dialog.execute_script("init(#{payload.to_json});")
        @toast = nil
      end

      def self.payload
        base = {
          'method'    => @method,
          'offset'    => @offset.to_i,
          'depth'     => @depth,
          'prefs'     => Sketchup.read_default(PREFS_SECTION, 'prefs', nil),
          'toast'     => @toast,
          'spent'     => @spent,
          'tree'      => [],
          'maxHeight' => 0,
          'tables'    => {},
          'totals'    => nil
        }
        return base if @report.nil?

        base['tree']      = @report[:tree]
        base['maxHeight'] = @report[:max_height]
        base['tables']    = @report[:tables]
        base['totals']    = {
          'area'     => Report.number(@report[:total_area]),
          'floors'   => @report[:floors],
          'problems' => @report[:problems]
        }
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
