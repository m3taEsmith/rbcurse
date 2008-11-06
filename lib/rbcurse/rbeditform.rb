=begin
  * Name: rbeditform
  * $Id$
  * Description   Edit form object with its own key_handler
  * Author: rkumar
  * Date: 2008-10-13 15:09 
  * License:
    This is free software; you can copy and distribute and modify
    this program under the term of Ruby's License
    (http://www.ruby-lang.org/LICENSE.txt)

=end

require 'ncurses'
require 'rbcurse/rbform'

include Ncurses
include Ncurses::Form

# An extension of the FORM class.
# Needed so i can attach key_handlers for various forms. 
# Got tired of mucking around with the user_object class.
#
# Arunachalesha 
# @version 

module Ncurses
  class WINDOW
    def ungetch(ch)
      Ncurses.ungetch(ch)
    end
    def getch
      begin
       Ncurses.keypad(stdscr,TRUE)  # should be done once only, required or UP DOWN wont work
       Ncurses.getch
        #window.getch
      rescue Interrupt => err
        3 # control-c
      end
    end
  end
end

class RBEditForm < RBForm 
#  attr_accessor :datasource # commented off on 2008-10-23 23:01 
  attr_accessor :rows_to_show
#  attr_reader   :form_save_proc    # 2008-10-18 16:56  # commented off 2008-10-23 23:01 

  def initialize(fields)
    super(fields)
    @form_status = nil;
    @values_hash = nil; #may pass a values hash to be used to display
    @field_hash = nil; #field name => field
    if block_given?
      yield self
    end
  end
  def set_application(app)
    super(app)
  end

  # Don't need to pass window any longer, that complicates matter.
  # It has to be the forms own window anyway.
  def handle_keys_loop(eform_win = nil)

    eform_win = form_win()
    field_init_proc = proc {
      field_init_hook()
      # removing calls to main, letem set it here 2008-10-23 19:05 
      #@main.field_init_hook(self) if @main.respond_to? "field_init_hook" # this needs to be called by keys too
    }
    field_term_proc = proc {
      field_term_hook()
      # commented off 2008-10-23 19:05 
      #@main.field_term_hook(self) if @main.respond_to? "field_term_hook"
    }

    form_init_proc = proc {
      form_init_hook() # 2008-11-02 14:22 
    }
    form_term_proc = proc {
      fire_handler :form_term, self
    }
    set_field_init(field_init_proc)
    set_field_term(field_term_proc)
    set_form_init(form_init_proc)
    set_form_term(form_term_proc)


    stdscr.refresh();

    Ncurses::Panel.update_panels
    Ncurses.doupdate()
    #set_defaults(nil)
    #fire_handler :form_init, self # XXX this aint getting fired dude perhaps installedtoo late
    form_init_proc.call
    #form_populate # 2008-11-02 14:36 pls overide init_proc to either use generic_form_populate
    # with  a key, or if you data, use set_defaults(rowdata)
    form_driver(REQ_FIRST_FIELD)
    form_driver(REQ_END_LINE);
    #while((ch = eform_win.getch()) )
    while(true)
      eform_win.refresh; # get the cursor back
      begin
        ch = eform_win.getch()
      rescue Interrupt
        ch =  3
      end
      @main.clear_error  # required but steals the cursor XXX oh no, this clears off helptext!!!

      case ch
      when 9 # tab
        form_driver(REQ_VALIDATION);
        form_driver(REQ_NEXT_FIELD);
        form_driver(REQ_END_LINE);
      when KEY_DOWN
        ret=form_driver(REQ_NEXT_LINE);
        if ret < 0
          form_driver(REQ_VALIDATION);
          form_driver(REQ_NEXT_FIELD);
          form_driver(REQ_END_LINE);
        end

      when 353 # 353 is tab with TERM=screen # 90  # back-tab
        # Go to previous field
        form_driver(REQ_VALIDATION);
        form_driver(REQ_PREV_FIELD);
        form_driver(REQ_END_LINE);

      when KEY_LEFT # Go to previous char
        form_driver(REQ_PREV_CHAR);

      when KEY_RIGHT # Go to next char
        form_driver(REQ_NEXT_CHAR);

      when KEY_BACKSPACE,127
        form_driver(REQ_DEL_PREV);
      when 153 # alt-h 
        helpproc()
      #when 24  # c-x
      #  handle_save
      when KEY_ENTER,10   # enter and c-j
        form_driver(REQ_NEXT_LINE);
        form_driver(REQ_INS_LINE);
      when KEY_UP # 11  
        ret=form_driver(REQ_PREV_LINE);
        if ret < 0
          form_driver(REQ_VALIDATION);
          form_driver(REQ_PREV_FIELD);
          form_driver(REQ_END_LINE);
        end
      when 1  # c-a
        form_driver(REQ_BEG_LINE);
      when 5  # c-e
        form_driver(REQ_END_LINE);
      when 165  # A-a
        form_driver(REQ_BEG_FIELD);
      when 180  # A-e
        form_driver(REQ_END_FIELD);
      when 130  # A-d
        form_driver(REQ_DEL_LINE);
      when 197, 3 # alt-Q alt-q C-c   in raw mode C-c is 3 not -1 
        form_driver(REQ_VALIDATION); # 2008-11-06 19:16 
        if form_changed?
          ret =  @main.askyesno(nil, "Form was changed. Wish to abandon ?")
          if !ret
            next
          else
            @main.print_status("Abandoning changes. Bye!")
            break
          end
        else
          break
        end
      else
        if ch < 0 or ch > 127 or ch.chr =~ /[[:cntrl:]]/
          #Ncurses.beep
          # either we just swallow it with a beep, or ret a -1
          # so it can be processed. Like saw a alt-q or F1 or quit command
          #consumed=@application.handle_unhandled_keys(ch, get_curr_item(), @selecteditems)
          begin
          consumed=handle_unhandled_keys(ch)
          @application.application_key_handler(ch) if !consumed
          rescue => err
            $log.error("ERROR: #{err}")
            $log.error(err.backtrace.join("\n"))
            @main.print_error("#{err}. Please check log file.")
          end
        else
          stdscr.refresh();
          form_driver(ch);
        end

      end # case
      eform_win.refresh; 
      Ncurses.doupdate()
      Ncurses::Panel.update_panels
      Ncurses.doupdate()
    end # while
  end # handle_keys_loop

  def field_init_hook()
    current_field.fire_handler(:on_enter, self) 
    fire_handler(:field_init, self) 
  end
  # all these atributes have to be handled properly and not in this fashion, XXX
  def field_term_hook()
    x = current_field
    fldname = x.user_object["name"]
    h = x.user_object
    if x.field_status == true
      begin
        value = x.get_value
      rescue FieldValidationException => err
        # NOT TESTED XXX
        @main.print_error( "ERROR: #{value} does not pass #{h['valid']}")
        $log.error err
        set_current_field(x);
        x.set_field_status(true);
        form_driver(REQ_PREV_FIELD); # seems it is the same as REQ_UP
        return
      end
      # added on 2008-10-23 17:55 TEST XXX
      current_field.fire_handler(:on_exit, self)  # what of return values
      fire_handler(:field_term, self)  # is this becoming an overkill, it can handle generic cases
      x.set_value(value.to_s)
      form_changed(true);
      notify_observers(fldname, @fields) # this should be only if changed, moved 2008-10-23 17:56 
    end
    x.set_field_status(false);
  end # field_term

  # 2008-11-02 14:22 
  def form_init_hook()
    fire_handler(:form_init, self) 
  end

  # btw, there is a REQ_FLD_CLEAR also.
  def clear_fields
    form_driver(REQ_FIRST_FIELD) 
    @fields.each{ |ff| ff.set_field_buffer(0,""); 
      #  ff.set_field_back(A_NORMAL); ff.user_object=nil; 
    }
    @application.wrefresh # 2008-10-08 18:03 
  end

  def helpproc()
    x = current_field
    text = x.user_object["help_text"]
    print_help(text.to_s) 
    #@main.footer_win.wrefresh # 2008-10-08 18:03 
  end

  ##
  # set a user defined form_save_proc, will be called when user presses save
  #
  # @param [block, #call] call the block
  # @return 
  def set_form_save_proc &block
    set_handler :form_save, block
  end

  ##
  # form_save: will call user defined proc or own crappy one when c-x pressed
  # @param [block, #call] call the block
  # @return 
  def form_save 
    fire_handler(:form_save, self)
    form_driver(REQ_FIRST_FIELD);
  end

  ##
  # set a user defined form_populate_proc, will be called whenever the form is to be
  # populated, at form startup and after each save. Can also be tied to other
  # keys such as next, prev etc.
  #
  # @param [block, #call] call the block
  # @return 
  def set_form_populate_proc &block
    set_handler :form_populate, block
  end
  def form_changed(bool)
    @form_status=bool;
  end

  def form_changed?
    @form_status
  end

  # returns current field hash, convenience method
  def get_current_field_hash
    x = current_field
    return x.user_object
  end 
  def get_field_by_name fname
    @fields.each{ |f|
      if f["name"] == fname
        return f
      end
    }
  end
  def get_another_field_hash fname
    @fields.each{ |f|
      if f["name"] == fname
        return f.user_object
      end
    }
  end 
  def get_another_field_hash_value fname,key
    hsh = get_another_field_hash(fname)
    return hsh[key]
  end
  ## returns the attribute of a field - only one
  # which is good for *most* fields 
  # but *not* for fieldtype, opts_on, opts_off, observes and a couple more
  # returns nil if no such attribute
  def get_current_field_attr_scalar(attrib)
    fhash = get_current_field_hash
    value = fhash[attrib][0] if fhash.include?attrib
    value
  end
  ## returns an array of attributes
  # can be used for opts, observes, fieldtype etc
  def get_current_field_attrs( attrib)
    fhash = get_current_field_hash
    value = fhash[attrib] if fhash.include?attrib
    value
  end


  ##
  # populates the form using the form populate proc if provided
  # or else our own proc
  #
  # @param none
  # @return none

  def form_populate
    fire_handler(:form_populate, self)
  end #  form_populate
  def set_values_hash vh
    @values_hash = vh
  end

  ## resets all fields 
  # If another hash is supplied it should set its values in
  # Any additional values in hash are ignored, we fetch what we need only
  def set_defaults(anotherhash = nil)
    #clear_current_values
    @fields.each { |ff|
      fielddef = ff.handle_default ''     # clumsy !
      fn = ff.name
      if anotherhash!= nil
        if anotherhash.include?fn
          fielddef = anotherhash[fn]
        end
      end
      if fielddef != nil
        ff.set_value(fielddef.to_s)
        ff.set_field_status(false) # won't be seen as modified
      end
    }
  end
  ##
  # Convenience method: returns a hash with field name as key, and field value as value
  def get_current_values_as_hash
    form_driver(REQ_VALIDATION); # 2008-10-31 23:27 
    #form_driver(REQ_PREV_FIELD);
    current = {}
    @fields.each { |ff|
      current[ ff["name"] ] = ff.get_value
    }
    return current
  end
  ##
  # Convenience method: returns a hash with field name as key, and FIELD as value
  def get_fields_as_hash
    return @field_hash if !@field_hash.nil?
    @fieldhash = {}
    @fields.each { |ff|
      @fieldhash[ ff["name"] ] = ff
    }
    return @fieldhash
  end
  # get the value of a field using its fieldname
  # cycles through field, i no longer keep that hash
  # since maintaining it was tricky/risky in some situations.
  def getv(fname)
    f = get_field_by_name fname
    return f.get_value
  end
  ## check each field
  # is it observing any others
  # if yes, then register itself as an observer
  # in the notify list of the other field
  def setup_observers()
    @fields.each { |fld|
      fhash = fld.user_object
      if fhash.include?"observes"
        watching = fhash["observes"]
        watching.each { |w|
          whash = get_another_field_hash w.to_s
          if !whash[w.to_s].include?"notifies"
            whash[w.to_s]["notifies"] = []
          end
          whash[w.to_s]["notifies"] << fldname
        }
      end
    }
  end
  def notify_observers(fldname, fields)
    observers = get_another_field_hash_value fldname,  "notifies" 
    return if !observers
    observers.each{ |oname|
      fhash = get_another_field_hash_value oname
      update_func = fhash["update_func"]
      @main.print_status(update_func)
      value = eval(update_func) #rescue 0;
      #update_current_value(oname, value.to_s)
      fields[fhash["index"]].set_field_buffer(0,value.to_s)
    }
  end
  def template( templateStr, values )
    templateStr.gsub( /\{\{(.*?)\}\}/ ) { values[ $1 ].to_str rescue "" }
  end

  ## prints help text for fields, or actions/events.
  def print_help(text)
    @main.print_status(text)
  end
  def handle_save
    form_driver(REQ_VALIDATION);
    form_driver(REQ_PREV_FIELD);
    field_term_hook() # this may prevent having to tab out before save
    form_save
    form_changed(false)
    #set_defaults
    form_populate
  end

  # obsolete ? XXX check and delete
  def set_defaults_hash outhash
    @fields.each{ |ff| 
      fn = ff["name"]
      value = outdata[fn]
      # value can be nil, need to check if user wants entered

      if value == nil || value.strip == ''
        value = ff["default"] rescue ''
        outdata[fn] = value
      end
    }
    outdata
  end
  ##
  # This could be when exiting form, or selecting new data, or moving to next row of findall
  # 2008-11-06 19:20 
  def abandon_changes?
    if form_changed?
      return @main.askyesno(nil, "Form was changed. Abandon changes ?")
    end
    return true
  end
 
  ### ADD HERE ###
end # class
