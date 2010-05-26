class Note < Gtk::Window
  @note = nil
  @buffer = nil
  @file = nil
  @deleted = false
  @title = nil

  def initialize(note = '')
    super

    @file = note
 
    unless note.nil? || note.length == 0
      @note = file_to_string(note)
      puts "Loading #{note}..."
    end

    signal_connect "destroy" do
      begin
        if @deleted
          raise "Note was deleted! No need to save..."
        end

        if @note.nil?
          if @buffer.text.length == 0
            raise "No data for new note creation. Ignoring..."
          end

          note = @title.to_filename
        end

        unless @note == @buffer.text
          puts "Saving Note: #{note}"
          save_note(note)
          $window.reload_notes

          $git.add('.')
          $git.commit_all("Saved note #{note}")
          puts "Note saved: #{note}"
        end
      rescue Exception => error
        puts error.message
      end
      self.destroy
    end

    set_default_size 400, 400

    if @note.nil?
      set_title "New Note"
    else 
      set_title note.to_title
      @title = note.to_title
    end

    init_ui

    show_all
  end
  def init_ui
    table = Gtk::Table.new 8, 4, false
  
    textview = Gtk::TextView.new
    if @note.nil?
      textview.buffer.text = ''
    else
      textview.buffer.text = @note
    end
    @buffer = textview.buffer

    @buffer.signal_connect('changed') do
      if @note.nil? && title == 'New Note'
        if @buffer.text =~ /\n/
          set_title @buffer.text.chomp!
          @title = @buffer.text.chomp!
          @buffer.text = ''
        end
      end
    end

    textview.wrap_mode = Gtk::TextTag::WRAP_WORD

    scrolled_win = Gtk::ScrolledWindow.new
    scrolled_win.border_width = 5
    scrolled_win.add(textview)
    scrolled_win.set_policy(Gtk::POLICY_AUTOMATIC, Gtk::POLICY_ALWAYS)

    toolbar = Gtk::Toolbar.new
    toolbar.set_toolbar_style Gtk::Toolbar::Style::ICONS

    rename_button = Gtk::ToolButton.new Gtk::Stock::SAVE_AS
    delete_button = Gtk::ToolButton.new Gtk::Stock::STOP

    toolbar.insert 0, rename_button
    toolbar.insert 1, delete_button
    
    if @note.nil?
      delete_button.sensitive = false
      rename_button.sensitive = false
    end

    unless !delete_button.sensitive?
      delete_button.signal_connect('clicked') do
        delete_note
      end
    end

    table.attach(toolbar, 1, 4, 1, 2, Gtk::FILL, Gtk::FILL, 0, 0)
    table.attach(scrolled_win, 1, 4, 3, 8, Gtk::FILL | Gtk::EXPAND, Gtk::FILL | Gtk::EXPAND, 1, 1)
    add table 

    textview.grab_focus()
  end

  def file_to_string(file)
    handle = File.open(BASE_DIR + '/notes/' + file)

    contents = ""
    handle.each do |line|
      contents << line
    end
    
    handle.close

    return contents
  end

  def save_note(file)
    handle = File.open(BASE_DIR + '/notes/' + file, 'w')
    lines = @buffer.text.split("\n")

    lines.each do |line|
      handle.puts line
    end

    handle.close
  end 

  def delete_note
    print "Deleting #{@file}... "
    $git.remove(BASE_DIR + '/notes/' + @file)
    $git.commit_all("Removed note #{@file}")
    print "OK\n"
     
    @deleted = true
    $window.reload_notes
    destroy
  end
end
