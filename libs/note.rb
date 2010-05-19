class Note < Gtk::Window
  @note = nil
  @buffer = nil
  @file = nil
  @deleted = false

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

          note = @buffer.text.split("\n").first.to_filename
        end
        puts "Saving Note: #{note}"
        save_note(note)
        $window.reload_notes

        $git.add('.')
        $git.commit_all("Saved note #{note}")
        puts "Note saved: #{note}"
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

    textview.wrap_mode = Gtk::TextTag::WRAP_WORD

    scrolled_win = Gtk::ScrolledWindow.new
    scrolled_win.border_width = 5
    scrolled_win.add(textview)
    scrolled_win.set_policy(Gtk::POLICY_AUTOMATIC, Gtk::POLICY_ALWAYS)

    delete_button = Gtk::Button.new("Delete")
    
    if @note.nil?
      delete_button.sensitive = false
    end

    unless !delete_button.sensitive?
      delete_button.signal_connect('clicked') do
        delete_note
      end
    end

    table.attach(scrolled_win, 1, 4, 1, 6, Gtk::FILL | Gtk::EXPAND, Gtk::FILL | Gtk::EXPAND, 1, 1)
    table.attach(delete_button, 2, 3, 7, 8, Gtk::FILL, Gtk::FILL, 5, 5)
    add table 
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
