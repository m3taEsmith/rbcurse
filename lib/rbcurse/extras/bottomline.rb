require "date"
require "erb"
require 'pathname'
=begin
  * Name          : bottomline.rb
  * Description   : routines for input at bottom of screen like vim, or anyother line  
  *               :
  * Author        : rkumar
  * Date          : 2010-10-25 12:45 
  * License       :
    Same as Ruby's License (http://www.ruby-lang.org/LICENSE.txt)

   The character input routines are from io.rb, however, the user-interface to the input
   is copied from the Highline project (James Earl Gray) with permission.
  
   May later use a Label and Field.

=end
module RubyCurses
  # some variables are polluting space of including app,
  # we should make this a class.
  attr_accessor :window
  attr_accessor :message_row
  class Bottomline 
    def initialize win=nil, row=nil
      @window = win
      @message_row = row
    end

  class QuestionError < StandardError
    # do nothing, just creating a unique error type
  end
  class Question
    # An internal HighLine error.  User code does not need to trap this.
    class NoAutoCompleteMatch < StandardError
      # do nothing, just creating a unique error type
    end

    #
    # Create an instance of HighLine::Question.  Expects a _question_ to ask
    # (can be <tt>""</tt>) and an _answer_type_ to convert the answer to.
    # The _answer_type_ parameter must be a type recognized by
    # Question.convert(). If given, a block is yeilded the new Question
    # object to allow custom initializaion.
    #
    def initialize( question, answer_type )
      # initialize instance data
      @question    = question
      @answer_type = answer_type
      
      @character    = nil
      @limit        = nil
      @echo         = true
      @readline     = false
      @whitespace   = :strip
      @_case         = nil
      @default      = nil
      @validate     = nil
      @above        = nil
      @below        = nil
      @in           = nil
      @confirm      = nil
      @gather       = false
      @first_answer = nil
      @directory    = Pathname.new(File.expand_path(File.dirname($0)))
      @glob         = "*"
      @responses    = Hash.new
      @overwrite    = false
      
      # allow block to override settings
      yield self if block_given?

      # finalize responses based on settings
      build_responses
    end
    
    # The ERb template of the question to be asked.
    attr_accessor :question
    # The type that will be used to convert this answer.
    attr_accessor :answer_type
    #
    # Can be set to +true+ to use HighLine's cross-platform character reader
    # instead of fetching an entire line of input.  (Note: HighLine's character
    # reader *ONLY* supports STDIN on Windows and Unix.)  Can also be set to
    # <tt>:getc</tt> to use that method on the input stream.
    #
    # *WARNING*:  The _echo_ and _overwrite_ attributes for a question are 
    # ignored when using the <tt>:getc</tt> method.  
    # 
    attr_accessor :character
    #
    # Allows you to set a character limit for input.
    # 
    # If not set, a default of 100 is used
    # 
    attr_accessor :limit
    #
    # Can be set to +true+ or +false+ to control whether or not input will
    # be echoed back to the user.  A setting of +true+ will cause echo to
    # match input, but any other true value will be treated as to String to
    # echo for each character typed.
    # 
    # This requires HighLine's character reader.  See the _character_
    # attribute for details.
    # 
    # *Note*:  When using HighLine to manage echo on Unix based systems, we
    # recommend installing the termios gem.  Without it, it's possible to type
    # fast enough to have letters still show up (when reading character by
    # character only).
    #
    attr_accessor :echo
    #
    # Use the Readline library to fetch input.  This allows input editing as
    # well as keeping a history.  In addition, tab will auto-complete 
    # within an Array of choices or a file listing.
    # 
    # *WARNING*:  This option is incompatible with all of HighLine's 
    # character reading  modes and it causes HighLine to ignore the
    # specified _input_ stream.
    # 
    # this messes up in ncurses RK 2010-10-24 12:23 
    attr_accessor :readline
    #
    # Used to control whitespace processing for the answer to this question.
    # See HighLine::Question.remove_whitespace() for acceptable settings.
    #
    attr_accessor :whitespace
    #
    # Used to control character case processing for the answer to this question.
    # See HighLine::Question.change_case() for acceptable settings.
    #
    attr_accessor :_case
    # Used to provide a default answer to this question.
    attr_accessor :default
    #
    # If set to a Regexp, the answer must match (before type conversion).
    # Can also be set to a Proc which will be called with the provided
    # answer to validate with a +true+ or +false+ return.
    #
    attr_accessor :validate
    # Used to control range checks for answer.
    attr_accessor :above, :below
    # If set, answer must pass an include?() check on this object.
    attr_accessor :in
    #
    # Asks a yes or no confirmation question, to ensure a user knows what
    # they have just agreed to.  If set to +true+ the question will be,
    # "Are you sure?  "  Any other true value for this attribute is assumed
    # to be the question to ask.  When +false+ or +nil+ (the default), 
    # answers are not confirmed.
    # 
    attr_accessor :confirm
    #
    # When set, the user will be prompted for multiple answers which will
    # be collected into an Array or Hash and returned as the final answer.
    # 
    # You can set _gather_ to an Integer to have an Array of exactly that
    # many answers collected, or a String/Regexp to match an end input which
    # will not be returned in the Array.
    # 
    # Optionally _gather_ can be set to a Hash.  In this case, the question
    # will be asked once for each key and the answers will be returned in a
    # Hash, mapped by key.  The <tt>@key</tt> variable is set before each 
    # question is evaluated, so you can use it in your question.
    # 
    attr_accessor :gather
    # 
    # When set to a non *nil* value, this will be tried as an answer to the
    # question.  If this answer passes validations, it will become the result
    # without the user ever being prompted.  Otherwise this value is discarded, 
    # and this Question is resolved as a normal call to HighLine.ask().
    # 
    attr_writer :first_answer
    #
    # The directory from which a user will be allowed to select files, when
    # File or Pathname is specified as an _answer_type_.  Initially set to
    # <tt>Pathname.new(File.expand_path(File.dirname($0)))</tt>.
    # 
    attr_accessor :directory
    # 
    # The glob pattern used to limit file selection when File or Pathname is
    # specified as an _answer_type_.  Initially set to <tt>"*"</tt>.
    # 
    attr_accessor :glob
    #
    # A Hash that stores the various responses used by HighLine to notify
    # the user.  The currently used responses and their purpose are as
    # follows:
    #
    # <tt>:ambiguous_completion</tt>::  Used to notify the user of an
    #                                   ambiguous answer the auto-completion
    #                                   system cannot resolve.
    # <tt>:ask_on_error</tt>::          This is the question that will be
    #                                   redisplayed to the user in the event
    #                                   of an error.  Can be set to
    #                                   <tt>:question</tt> to repeat the
    #                                   original question.
    # <tt>:invalid_type</tt>::          The error message shown when a type
    #                                   conversion fails.
    # <tt>:no_completion</tt>::         Used to notify the user that their
    #                                   selection does not have a valid
    #                                   auto-completion match.
    # <tt>:not_in_range</tt>::          Used to notify the user that a
    #                                   provided answer did not satisfy
    #                                   the range requirement tests.
    # <tt>:not_valid</tt>::             The error message shown when
    #                                   validation checks fail.
    #
    attr_reader :responses
    #
    # When set to +true+ the question is asked, but output does not progress to
    # the next line.  The Cursor is moved back to the beginning of the question
    # line and it is cleared so that all the contents of the line disappear from
    # the screen.
    #
    attr_accessor :overwrite

    #
    # If the user presses tab in ask(), then this proc is used to fill in
    # values. Typically, for files. e.g.
    #
    #    q.completion_proc = Proc.new {|str| Dir.glob(str +"*") }
    #
    attr_accessor :completion_proc
    #
    # text to be shown if user presses M-h
    #
    attr_accessor :helptext
    attr_accessor :color_pair
   
    #
    # Returns the provided _answer_string_ or the default answer for this
    # Question if a default was set and the answer is empty.
    # NOTE: in our case, the user actually edits this value (in highline it
    # is used if user enters blank)
    #
    def answer_or_default( answer_string )
      if answer_string.length == 0 and not @default.nil?
        @default
      else
        answer_string
      end
    end
    
    #
    # Called late in the initialization process to build intelligent
    # responses based on the details of this Question object.
    #
    def build_responses(  )
      ### WARNING:  This code is quasi-duplicated in     ###
      ### Menu.update_responses().  Check there too when ###
      ### making changes!                                ###
      append_default unless default.nil?
      @responses = { :ambiguous_completion =>
                       "Ambiguous choice.  " +
                       "Please choose one of #{@answer_type.inspect}.",
                     :ask_on_error         =>
                       "?  ",
                     :invalid_type         =>
                       "You must enter a valid #{@answer_type}.",
                     :no_completion        =>
                       "You must choose one of " +
                       "#{@answer_type.inspect}.",
                     :not_in_range         =>
                       "Your answer isn't within the expected range " +
                       "(#{expected_range}).",
                     :not_valid            =>
                       "Your answer isn't valid (must match " +
                       "#{@validate.inspect})." }.merge(@responses)
      ### WARNING:  This code is quasi-duplicated in     ###
      ### Menu.update_responses().  Check there too when ###
      ### making changes!                                ###
    end
    
    #
    # Returns the provided _answer_string_ after changing character case by
    # the rules of this Question.  Valid settings for whitespace are:
    #
    # +nil+::                        Do not alter character case. 
    #                                (Default.)
    # <tt>:up</tt>::                 Calls upcase().
    # <tt>:upcase</tt>::             Calls upcase().
    # <tt>:down</tt>::               Calls downcase().
    # <tt>:downcase</tt>::           Calls downcase().
    # <tt>:capitalize</tt>::         Calls capitalize().
    # 
    # An unrecognized choice (like <tt>:none</tt>) is treated as +nil+.
    # 
    def change_case( answer_string )
      if [:up, :upcase].include?(@_case)
        answer_string.upcase
      elsif [:down, :downcase].include?(@_case)
        answer_string.downcase
      elsif @_case == :capitalize
        answer_string.capitalize
      else
        answer_string
      end
    end

    #
    # Transforms the given _answer_string_ into the expected type for this
    # Question.  Currently supported conversions are:
    #
    # <tt>[...]</tt>::         Answer must be a member of the passed Array. 
    #                          Auto-completion is used to expand partial
    #                          answers.
    # <tt>lambda {...}</tt>::  Answer is passed to lambda for conversion.
    # Date::                   Date.parse() is called with answer.
    # DateTime::               DateTime.parse() is called with answer.
    # File::                   The entered file name is auto-completed in 
    #                          terms of _directory_ + _glob_, opened, and
    #                          returned.
    # Float::                  Answer is converted with Kernel.Float().
    # Integer::                Answer is converted with Kernel.Integer().
    # +nil+::                  Answer is left in String format.  (Default.)
    # Pathname::               Same as File, save that a Pathname object is
    #                          returned.
    # String::                 Answer is converted with Kernel.String().
    # Regexp::                 Answer is fed to Regexp.new().
    # Symbol::                 The method to_sym() is called on answer and
    #                          the result returned.
    # <i>any other Class</i>:: The answer is passed on to
    #                          <tt>Class.parse()</tt>.
    #
    # This method throws ArgumentError, if the conversion cannot be
    # completed for any reason.
    # 
    def convert( answer_string )
      if @answer_type.nil?
        answer_string
      elsif [Float, Integer, String].include?(@answer_type)
        Kernel.send(@answer_type.to_s.to_sym, answer_string)
      elsif @answer_type == Symbol
        answer_string.to_sym
      elsif @answer_type == Regexp
        Regexp.new(answer_string)
      elsif @answer_type.is_a?(Array) or [File, Pathname].include?(@answer_type)
        # cheating, using OptionParser's Completion module
        choices = selection
        #choices.extend(OptionParser::Completion)
        #answer = choices.complete(answer_string)
        answer = choices # bug in completion of optparse
        if answer.nil?
          raise NoAutoCompleteMatch
        end
        if @answer_type.is_a?(Array)
          answer.last
        elsif @answer_type == File
          File.open(File.join(@directory.to_s, answer.last))
        else
          Pathname.new(File.join(@directory.to_s, answer.last))
        end
      elsif [Date, DateTime].include?(@answer_type) or @answer_type.is_a?(Class)
        @answer_type.parse(answer_string)
      elsif @answer_type.is_a?(Proc)
        @answer_type[answer_string]
      end
    end

    # Returns a english explination of the current range settings.
    def expected_range(  )
      expected = [ ]

      expected << "above #{@above}" unless @above.nil?
      expected << "below #{@below}" unless @below.nil?
      expected << "included in #{@in.inspect}" unless @in.nil?

      case expected.size
      when 0 then ""
      when 1 then expected.first
      when 2 then expected.join(" and ")
      else        expected[0..-2].join(", ") + ", and #{expected.last}"
      end
    end

    # Returns _first_answer_, which will be unset following this call.
    def first_answer( )
      @first_answer
    ensure
      @first_answer = nil
    end
    
    # Returns true if _first_answer_ is set.
    def first_answer?( )
      not @first_answer.nil?
    end
    
    #
    # Returns +true+ if the _answer_object_ is greater than the _above_
    # attribute, less than the _below_ attribute and included?()ed in the
    # _in_ attribute.  Otherwise, +false+ is returned.  Any +nil+ attributes
    # are not checked.
    #
    def in_range?( answer_object )
      (@above.nil? or answer_object > @above) and
      (@below.nil? or answer_object < @below) and
      (@in.nil? or @in.include?(answer_object))
    end
    
    #
    # Returns the provided _answer_string_ after processing whitespace by
    # the rules of this Question.  Valid settings for whitespace are:
    #
    # +nil+::                        Do not alter whitespace.
    # <tt>:strip</tt>::              Calls strip().  (Default.)
    # <tt>:chomp</tt>::              Calls chomp().
    # <tt>:collapse</tt>::           Collapses all whitspace runs to a
    #                                single space.
    # <tt>:strip_and_collapse</tt>:: Calls strip(), then collapses all
    #                                whitspace runs to a single space.
    # <tt>:chomp_and_collapse</tt>:: Calls chomp(), then collapses all
    #                                whitspace runs to a single space.
    # <tt>:remove</tt>::             Removes all whitespace.
    # 
    # An unrecognized choice (like <tt>:none</tt>) is treated as +nil+.
    # 
    # This process is skipped, for single character input.
    # 
    def remove_whitespace( answer_string )
      if @whitespace.nil?
        answer_string
      elsif [:strip, :chomp].include?(@whitespace)
        answer_string.send(@whitespace)
      elsif @whitespace == :collapse
        answer_string.gsub(/\s+/, " ")
      elsif [:strip_and_collapse, :chomp_and_collapse].include?(@whitespace)
        result = answer_string.send(@whitespace.to_s[/^[a-z]+/])
        result.gsub(/\s+/, " ")
      elsif @whitespace == :remove
        answer_string.gsub(/\s+/, "")
      else
        answer_string
      end
    end

    #
    # Returns an Array of valid answers to this question.  These answers are
    # only known when _answer_type_ is set to an Array of choices, File, or
    # Pathname.  Any other time, this method will return an empty Array.
    # 
    def selection(  )
      if @answer_type.is_a?(Array)
        @answer_type
      elsif [File, Pathname].include?(@answer_type)
        Dir[File.join(@directory.to_s, @glob)].map do |file|
          File.basename(file)
        end
      else
        [ ]
      end      
    end
    
    # Stringifies the question to be asked.
    def to_str(  )
      @question
    end

    #
    # Returns +true+ if the provided _answer_string_ is accepted by the 
    # _validate_ attribute or +false+ if it's not.
    # 
    # It's important to realize that an answer is validated after whitespace
    # and case handling.
    #
    def valid_answer?( answer_string )
      @validate.nil? or 
      (@validate.is_a?(Regexp) and answer_string =~ @validate) or
      (@validate.is_a?(Proc)   and @validate[answer_string])
    end
    
    private
    
    #
    # Adds the default choice to the end of question between <tt>|...|</tt>.
    # Trailing whitespace is preserved so the function of HighLine.say() is
    # not affected.
    #
    def append_default(  )
      if @question =~ /([\t ]+)\Z/
        @question << "|#{@default}|#{$1}"
      elsif @question == ""
        @question << "|#{@default}|  "
      elsif @question[-1, 1] == "\n"
        @question[-2, 0] =  "  |#{@default}|"
      else
        @question << "  |#{@default}|"
      end
    end
  end # class

  def ask(question, answer_type=String, &details)
    clear_line 80
    @question ||= Question.new(question, answer_type, &details)
    say(@question) #unless @question.echo == true

    @completion_proc = @question.completion_proc
    @default = @question.default
    @helptext = @question.helptext

    begin
      @answer = @question.answer_or_default(get_response) 
      unless @question.valid_answer?(@answer)
        explain_error(:not_valid)
        raise QuestionError
      end
      
      @answer = @question.convert(@answer)
      
      if @question.in_range?(@answer)
        if @question.confirm
          # need to add a layer of scope to ask a question inside a
          # question, without destroying instance data
          context_change = self.class.new(@input, @output, @wrap_at, @page_at)
          if @question.confirm == true
            confirm_question = "Are you sure?  "
          else
            # evaluate ERb under initial scope, so it will have
            # access to @question and @answer
            template  = ERB.new(@question.confirm, nil, "%")
            confirm_question = template.result(binding)
          end
          unless context_change.agree(confirm_question)
            explain_error(nil)
            raise QuestionError
          end
        end
        
        @answer
      else
        explain_error(:not_in_range)
        raise QuestionError
      end
    rescue QuestionError
      retry
    rescue ArgumentError, NameError => error
      raise
      raise if error.is_a?(NoMethodError)
      if error.message =~ /ambiguous/
        # the assumption here is that OptionParser::Completion#complete
        # (used for ambiguity resolution) throws exceptions containing 
        # the word 'ambiguous' whenever resolution fails
        explain_error(:ambiguous_completion)
      else
        explain_error(:invalid_type)
      end
      retry
    rescue Question::NoAutoCompleteMatch
      explain_error(:no_completion)
      retry
    ensure
      @question = nil    # Reset Question object.
    end
  end
  
  #
  # The basic output method for HighLine objects.  
  #
  # The _statement_ parameter is processed as an ERb template, supporting
  # embedded Ruby code.  The template is evaluated with a binding inside 
  # the HighLine instance.
  # NOTE: modified from original highline, does not care about space at end of
  # question. Also, ansi color constants will not work. Be careful what ruby code
  # you pass in.
  #
  def say statement, config={}
    case statement
    when Question
      $log.debug "INSIDE QUESTION  1" if $log.debug? 
      if config.has_key? :color_pair
        $log.debug "INSIDE QUESTION 2 " if $log.debug? 
      else
        $log.debug "XXXX SAY using #{statement.color_pair} " if $log.debug? 
        config[:color_pair] = statement.color_pair
      end
    else
      $log.debug "XXX INSDIE SAY #{statement.class}  " if $log.debug? 
    end
    statement =  statement.to_str
    template  = ERB.new(statement, nil, "%")
    statement = template.result(binding)
    #puts statement
    @prompt_length = statement.length # required by ask since it prints after 
    @statement = statement # 
    print_str statement, config
  end
  # A helper method for sending the output stream and error and repeat
  # of the question.
  #
  def explain_error( error )
    say(@question.responses[error]) unless error.nil?
    if @question.responses[:ask_on_error] == :question
      say(@question)
    elsif @question.responses[:ask_on_error]
      say(@question.responses[:ask_on_error])
    end
  end

  def print_str(text, config={})
    win = config.fetch(:window, @window) # assuming its in App
    x = config.fetch :x, @message_row # Ncurses.LINES-1
    y = config.fetch :y, 0
    color = config[:color_pair] || $datacolor
    raise "no window for ask print" unless win
    color=Ncurses.COLOR_PAIR(color);
    win.attron(color);
    #win.mvprintw(x, y, "%-40s" % text);
    win.mvprintw(x, y, "%s" % text);
    win.attroff(color);
    win.refresh
  end

  # actual input routine, gets each character from user, taking care of echo, limit,
  # completion proc, and some control characters such as C-a, C-e, C-k
  # Taken from io.rb, has some improvements to it. However, does not print the prompt
  # any longer
  def rbgetstr
    r = @message_row
    c = 0
    win = @window
    @limit = @question.limit
    maxlen = @limit || 100 # fixme
  
 
    raise "rbgetstr got no window. io.rb" if win.nil?
    ins_mode = false
    oldstr = nil # for tab completion, origal word entered by user
    default = @default || ""

    len = @prompt_length

    # clear the area of len+maxlen
    color = $datacolor
    str = default
    #clear_line len+maxlen+1
    #print_str(prompt+str)
    print_str(str, :y => @prompt_length+0) if @default
    len = @prompt_length + str.length
    begin
      Ncurses.noecho();
      curpos = str.length
      prevchar = 0
      entries = nil
      while true
        ch=win.getchar()
        #$log.debug " rbgetstr got ch:#{ch}, str:#{str}. "
        case ch
        when 3 # -1 # C-c  # sometimes this causes an interrupt and crash
          return -1, nil
        when ?\C-g.getbyte(0)                              # ABORT, emacs style
          return -1, nil
        when 10, 13 # hits ENTER, complete entry and return
          break
        when ?\C-h.getbyte(0), ?\C-?.getbyte(0), KEY_BSPACE # delete previous character/backspace
          len -= 1 if len > @prompt_length
          curpos -= 1 if curpos > 0
          str.slice!(curpos)
          clear_line len+maxlen+1, @prompt_length
        when 330 # delete character on cursor
          str.slice!(curpos) #rescue next
          clear_line len+maxlen+1, @prompt_length
        when ?\M-h.getbyte(0) #                            HELP KEY
          helptext = @helptext || "No help provided"
          print_help(helptext) 
          clear_line len+maxlen+1
          print_str @statement # UGH
          #return 7, nil
          #next
        when KEY_LEFT
          curpos -= 1 if curpos > 0
          len -= 1 if len > @prompt_length
          win.wmove r, c+len # since getchar is not going back on del and bs
          next
        when KEY_RIGHT
          if curpos < str.length
            curpos += 1 #if curpos < str.length
            len += 1 
            win.wmove r, c+len # since getchar is not going back on del and bs
          end
          next
        when ?\C-a.getbyte(0)
          #olen = str.length
          clear_line len+maxlen+1, @prompt_length
          len -= curpos
          curpos = 0
          win.wmove r, c+len # since getchar is not going back on del and bs
        when ?\C-e.getbyte(0)
          olen = str.length
          len += (olen - curpos)
          curpos = olen
          clear_line len+maxlen+1, @prompt_length
          win.wmove r, c+len # since getchar is not going back on del and bs

        when ?\M-i.getbyte(0) 
          ins_mode = !ins_mode
          next
        when ?\C-k.getbyte(0)
          str.slice!(curpos..-1) #rescue next
          clear_line len+maxlen+1, @prompt_length
        when KEY_TAB # TAB
          if !@completion_proc.nil?
            # place cursor at end of completion
            # after all completions, what user entered should come back so he can edit it
            if prevchar == 9
              if !entries.nil? and !entries.empty?
                olen = str.length
                str = entries.delete_at(0)
                curpos = str.length
                len += str.length - olen
                clear_line len+maxlen+1, @prompt_length
              else
                olen = str.length
                str = oldstr if oldstr
                curpos = str.length
                len += str.length - olen
                clear_line len+maxlen+1, @prompt_length
                prevchar = ch = nil # so it can start again completing
              end
            else
              tabc = @completion_proc unless tabc
              next unless tabc
              oldstr = str.dup
              olen = str.length
              entries = tabc.call(str)
              $log.debug " tab got #{entries} "
              str = entries.delete_at(0) unless entries.nil? or entries.empty?
              if str
                curpos = str.length
                len += str.length - olen
              else
                alert "NO MORE 2"
              end
            end
          end
        when ?\C-a.getbyte(0) .. ?\C-z.getbyte(0)
          Ncurses.beep
          #clear_line len+maxlen+1, @prompt_length
          #clear
          #next
        else
          #if validints.include?ch
          #print_status("Found in validints")
          #return ch, nil
          #else
          if ch < 0 || ch > 255
            Ncurses.beep
            next
          end
          # if control char, beep
          if ch.chr =~ /[[:cntrl:]]/
            Ncurses.beep
            next
          end
          # we need to trap KEY_LEFT and RIGHT and what of UP for history ?
          #end
          #str << ch.chr
          if ins_mode
            str[curpos] = ch.chr
          else
            str.insert(curpos, ch.chr)
          end
          len += 1
          curpos += 1
          break if str.length >= maxlen
        end
        case @question.echo
        when true
          print_str(str, :y => @prompt_length+0)
        when false
          # noop
        else
          print_str(@question.echo * str.length, :y => @prompt_length+0)
        end
        win.wmove r, c+len # more for arrow keys, curpos may not be end
        prevchar = ch
      end
      str = default if str == ""
    ensure
      Ncurses.noecho();
      #x restore_application_key_labels # must be done after using print_key_labels
    end
    return 0, str
  end
  # clears line from 0, not okay in some cases
  def clear_line len=100, from=0
    print_str("%-*s" % [len," "], :y => from)
  end

  def print_help(helptext)
    # best to popup a window and hsow that with ENTER to dispell
    print_str("%-*s" % [helptext.length+2," "])
    print_str("%s" % helptext)
    sleep(5)
  end
  def get_response
    return @question.first_answer if @question.first_answer?
    # we always use character reader, so user's value does not matter

    #if @question.character.nil?
    #  if @question.echo == true #and @question.limit.nil?
    ret, str = rbgetstr
    if ret == 0
      return @question.change_case(@question.remove_whitespace(str))                
    end
    return ""
  end
  def agree( yes_or_no_question, character = nil )
    ask(yes_or_no_question, lambda { |yn| yn.downcase[0] == ?y}) do |q|
      q.validate                 = /\Ay(?:es)?|no?\Z/i
      q.responses[:not_valid]    = 'Please enter "yes" or "no".'
      q.responses[:ask_on_error] = :question
      q.character                = character
      
      yield q if block_given?
    end
  end
  end  # module
end # module
if __FILE__ == $PROGRAM_NAME

      #tabc = Proc.new {|str| Dir.glob(str +"*") }
  require 'rbcurse/app'
  require 'forwardable'
  #include Bottomline

  $tt = Bottomline.new
  module Kernel
    extend Forwardable
    def_delegators :$tt, :ask, :say, :agree, :choose
  end
  App.new do 
    header = app_header "rbcurse 1.2.0", :text_center => "**** Demo", :text_right =>"New Improved!", :color => :black, :bgcolor => :white, :attr => :bold 
    message "Press F1 to exit from here"
    $tt.window = @window; $tt.message_row = @message_row
    #@tt = Bottomline.new @window, @message_row
    #extend Forwardable
    #def_delegators :@tt, :ask, :say, :agree, :choose

    #stack :margin_top => 2, :margin => 5, :width => 30 do
    #end # stack
    #-----------------#------------------
    entry = {}
    entry[:address]     = ask("Address?  ") { |q| q.color_pair = $promptcolor }
    entry[:company]     = ask("Company?  ") { |q| q.default = "none" }
    entry[:password]        = ask("password?  ") { |q|
      q.echo = '*'
      q.limit = 4
    }
    entry[:file]       = ask("File?  ", Pathname)  do |q| 
      q.completion_proc = Proc.new {|str| Dir.glob(str +"*") }
      q.helptext = "Enter start of filename and tab to get completion"
    end
=begin
    entry[:state]       = ask("State?  ") do |q|
      q._case     = :up
      q.validate = /\A[A-Z]{2}\Z/
      q.helptext = "Enter 2 characters for your state"
    end
    entry[:zip]         = ask("Zip?  ") do |q|
    q.validate = /\A\d{5}(?:-?\d{4})?\Z/
    end
    entry[:phone]       = ask( "Phone?  ",
    lambda { |p| p.delete("^0-9").
    sub(/\A(\d{3})/, '(\1) ').
    sub(/(\d{4})\Z/, '-\1') } ) do |q|
    q.validate              = lambda { |p| p.delete("^0-9").length == 10 }
    q.responses[:not_valid] = "Enter a phone numer with area code."
    end
    entry[:age]         = ask("Age?  ", Integer) { |q| q.in = 0..105 }
    entry[:birthday]    = ask("Birthday?  ", Date)
    entry[:interests]   = ask( "Interests?  (comma separated list)  ",
                              lambda { |str| str.split(/,\s*/) } )
    entry[:description] = ask("Enter a description for this contact.") do |q|
      q.whitespace = :strip_and_collapse
  end
=end
  $log.debug "ENTRY: #{entry}  " if $log.debug? 
  #puts entry
end # app
end # FILE
