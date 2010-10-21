require 'rbcurse/app'
require 'fileutils'
require './rmail'
# You need mailread.rb which is present in 1.8, but missing in 1.9
# I've loaded it here ... http://gist.github.com/634166 with line encoding
# You need to fix paths of local mbox files

App.new do 
  ht = 24
  @messages = nil
  $unread_hash = {}
  @tv = nil
  borderattrib = :reverse
  @header = app_header "rbcurse 1.2.0", :text_center => "Yet Another Email Client that sucks", :text_right =>"", :color => :black, :bgcolor => :white#, :attr =>  Ncurses::A_BLINK
  message "Press F1 to exit ...................................................."


  stack :margin_top => 1, :margin => 0, :width => :EXPAND do
    # NOTE: please fix the next 2 lines based on where your mbox files reside
    model = ["~/mbox"] 
    others = "~/mail/"
    boxes = Dir.new(File.expand_path(others)).entries
    boxes.delete(".")
    boxes.delete("..")
    boxes = boxes.collect do |e| others+e; end
    model.push *boxes

    #@vim = MasterDetail.new @form, :row => 1, :col => 1, :width => :EXPAND
    @vim = master_detail :width => :EXPAND
    @dirs = list_box :list => model, :height => ht, :border_attrib => borderattrib, :suppress_borders => true
    @dirs.one_key_selection = false
    
    # we override so as to only print basename. Also, print unread count 
    def @dirs.convert_value_to_text(text, crow)
      str = File.basename(text)
      if $unread_hash.has_key?(str)
        str << " (#{$unread_hash[str]})"
      else
        str 
      end
    end
    @vim.set_left_component @dirs

    
    @mails = []
    headings = %w{ Stat #  Date From Subject }
    @lb2 = tabular_widget :suppress_borders => true
    @lb2.columns = headings
    @lb2.column_align 1, :right
    @lb2.column_align 0, :right
    @lb2.header_fgcolor :white
    @lb2.header_bgcolor :cyan
    @vim.set_right_top_component @lb2
    @dirs.bind :PRESS do |e|
      @lines = []
      mx = Mbox.new File.expand_path(e.text)
      mx.array_each do |text|
        @lines << text
      end
      message " #{e.text} has #{@lines.size} messages"
      $unread_hash[File.basename(e.text)] = mx.unread_count
      @lb2.set_content @lines
      @lb2.estimate_column_widths=true
      @messages = mx.mails()
    end
    @lb2.bind :PRESS do |e|
      case @lb2
      when RubyCurses::TabularWidget
        if e.action_command == :header
          # now does sorting on multiple keys
        else
          index = e.source.current_index - 1 # this should check what first data index is
          if index >= 0
            @tv.set_content(@messages[index].body, :WRAP_WORD)
          end
        end
      else
        @tv.set_content(@messages[e.source.current_index].body, :WRAP_WORD)
      end
    end
    @lb2.bind :ENTER_ROW do |e|
      @header.text_right "Row #{e.current_index} of #{@messages.size} "
    end

    @tv = @vim.set_right_bottom_component "Email body comes here. "
    @tv.suppress_borders true
    @tv.border_attrib = borderattrib
  end # stack
end # app
