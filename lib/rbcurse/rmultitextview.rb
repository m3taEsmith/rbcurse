=begin
  * Name: MultiTextView 
  * Description   View text in this widget for multiple files
  * Author: rkumar (arunachalesha)
  * file created 2010-03-11 08:05 
  --------
  * License:
    Same as Ruby's License (http://www.ruby-lang.org/LICENSE.txt)

=end
require 'rubygems'
require 'ncurses'
require 'logger'
require 'rbcurse'
require 'rbcurse/rtextview'
require 'rbcurse/listscrollable'

include Ncurses
include RubyCurses
module RubyCurses
  extend self

  ##
  # A viewable read only box. Can scroll. 
  # Extends TextView with ability to load more than one file or content
  # and switch between files (buffers).
  # NOTE: ideally, i should be able to dynamically add this functionality to either Textview
  # or TextArea or even ListBox or Table someday. Should then be a Module rather than a class.
  class MultiTextView < TextView
    include ListScrollable

    def initialize form = nil, config={}, &block
      #@list = []
      super
      @bmanager = BufferManager.new self
      #@content_rows = @list.length
    end
    def init_vars
      super
      bind_key(?:, :buffer_menu)
      bind_key(?e, :file_edit)
    end
    ## returns current buffer
    # @return  [RBuffer] current buffer
    def current_buffer
      @bmanager.current
    end
    ## 
    # send in a list
    # e.g.         set_content File.open("README.txt","r").readlines
    # set wrap at time of passing :WRAP_NONE :WRAP_WORD
    def set_content list, wrap = :WRAP_NONE
      ret = super
      @bmanager.add_content @list
      # set in current buffer in bm, if none, then in 0
      # get this as current one XXX
      return ret
    end
    # multi-textview
    def handle_key ch
      # put list as current list and buffer too then super
      #@current_buffer = @bmanager.current
      #@list = @current_buffer.list
      @buffer = @list[@current_index]
      #@buffer = @bmanager.current
      ret = super
      # check for any keys not handled and check our own ones
      return ret # 
    end
    ## prompt user for a filename to read in
    def getfilename prompt="Enter filename: ", maxlen=90
      tabc = Proc.new {|str| Dir.glob(str +"*") }
      config={}; config[:tab_completion] = tabc
      #config[:default] = "defaulT"
      $log.debug " inside getstr before call #{@row} +  #{@height}  "
      #ret, str = rbgetstr(@form.window, @row+@height-1, @col+1, prompt, maxlen, config)
      ret, str = rbgetstr(@form.window, 24, 15, prompt, maxlen, config)
      $log.debug " rbgetstr returned #{ret} , #{str} "
      return "" if ret != 0
      return str
    end
    # this is just a test of the simple "most" menu
    # can use this for next, prev, first, last, new, delete, overwrite etc
    def buffer_menu
      menu = PromptMenu.new self 
      menu.add(menu.create_mitem( 'e', "edit a file", "opened file ", :file_edit ))
      menu.add(menu.create_mitem( 'o', "overwrite file", "opened a file ", :file_overwrite ))
      menu.add(menu.create_mitem( 'l', "list buffers", "list buffers ", :buffers_list ))
      item = menu.create_mitem( 'b', "Buffer Options", "Buffer Options" )
      menu1 = PromptMenu.new( self, "Buffer Options")
      menu1.add(menu1.create_mitem( 'n', "Next", "Switched to Next Buffer", :buffer_next ))
      menu1.add(menu1.create_mitem( 'p', "Prev", "Switched to Next Buffer", :buffer_previous ))
      menu1.add(menu1.create_mitem( 'f', "First", "Switched to First Buffer", :buffer_first ))
      menu1.add(menu1.create_mitem( 'l', "Last", "Switched to Last Buffer", :buffer_last ))
      item.action = menu1
      menu.add(item)
      # how do i know what's available. the application or window should know where to place
      menu.display @form.window, 23, 1, $datacolor #, menu
    end

    %w[next previous first last].each do |pos|
      eval(
           "def _buffer_#{pos}
              @current_buffer = @bmanager.#{pos}
              set_current_buffer
           end"
          )
    end

    def buffer_next
      @current_buffer = @bmanager.next
      set_current_buffer
    end
    def buffer_previous
      @current_buffer = @bmanager.previous
      $log.debug " buffer_prev got #{@current_buffer} "
      set_current_buffer
    end
    def buffer_first
      @current_buffer = @bmanager.first
      $log.debug " buffer_first got #{@current_buffer} "
      set_current_buffer
    end
    def buffer_last
      @current_buffer = @bmanager.last
      $log.debug " buffer_last got #{@current_buffer} "
      set_current_buffer
    end
    def buffers_list
      $log.debug " TODO buffers_list: #{@bmanager.size}  "
    end
    def file_edit
      file = getfilename()
      $log.debug " got file_edit: #{file} "
      return if file == ""
      @current_buffer = @bmanager.add file, file
      $log.debug " file edit got cb : #{@current_buffer} "
      set_current_buffer
    end
    def set_current_buffer
      @current_index = @current_buffer.current_index
      @curpos = @current_buffer.curpos
      @title = @current_buffer.title
      @list = @current_buffer.list
    end
  end # class multitextview
  ##
  # Handles multiple buffers, navigation, maintenance etc
  # Instantiated at startup of MultiTextView
  #
  class BufferManager
    def initialize source
      @source = source
      @buffers = [] # contains RBuffer
      @counter = 0
      # for each buffer i need to store data, current_index (row), curpos (col offset) and title (filename).
    end
    ##
    # @return [RBuffer] current buffer/file
    ##
    def current
      @buffers[@counter]
    end
    ##
    # Would have liked to just return next buffer and not get lost in details of caller
    #
    # @return [RBuffer] next buffer/file
    ##
    def next
      @counter += 1
      @counter = 0 if @counter >= @buffers.size
      @buffers[@counter]
    end
    ##
    # @return [RBuffer] previous buffer/file
    ##
    def previous
      $log.debug " previous bs: #{@buffers.size} "
      @counter -= 1
      return last() if @counter < 0
      $log.debug " previous ctr  #{@counter} "
      @buffers[@counter]
    end
    def first
      @counter = 0
      @buffers[@counter]
    end
    def last
      @counter = @buffers.size - 1
      @buffers[@counter]
    end
    ##
    def delete_at index=@counter
      @buffers.delete_at index
    end
    def delete_by_name name
      @buffers.delete_if {|b| b.filename == name }
    end
    def insert filename, position, title=nil
      # read up file
      list = @source.set_content File.open(filename,"r").readlines
      # set new RBuffer
      title = filename unless title
      raise "invalid value for list, Should be an array #{list.class} " unless list.is_a? Array
      anew = RBuffer.new(list, 0, 0, filename, title)
      #@buffers << anew
      @buffers.insert position, anew
      return anew
    end
    def add filename, title=nil
      insert filename, @buffers.size, title
    end
    def insert_content str, position,  title="Untitled"
      case str
      when String
        # put str into list
        @source.set_content str
        list = @list
      when Array
        list = str
      end
      anew = RBuffer.new(list, 0, 0, "", title)
      #@buffers << anew
      @buffers.insert position, anew
      return anew
    end
    # add content (array or str) to buffer list as a new buffer
    def add_content str, title="Untitled"
      $log.debug " inside BUFFER MANAGER "
      insert_content str,  @buffers.size, title
    end
    def size
      @buffers.size
    end
    alias :count :size
  end
  RBuffer = Struct.new(:list, :current_index, :curpos, :filename, :title) do
    def xxx
    end
  end

end # modul