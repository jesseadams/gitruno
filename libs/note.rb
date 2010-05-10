class Note < Gtk::Window
  @note = nil
  @buffer = nil

  def initialize(note = nil)
    super
 
    unless note.nil?
      @note = file_to_string(note)
      puts "Loading #{note}..."
    end

    signal_connect "destroy" do
      puts "Saving Note: #{note}"
      save_note(note)

      begin
        $git.add('.')
        $git.commit("Saved note #{note}")
        puts "Note saved: #{note}"
      rescue Exception => error
        puts error.message
      end
      self.destroy
    end

    set_default_size 400, 400
    set_title note.to_title

    init_ui

    show_all
  end
  def init_ui
    textview = Gtk::TextView.new
    textview.buffer.text = @note
    @buffer = textview.buffer

    scrolled_win = Gtk::ScrolledWindow.new
    scrolled_win.border_width = 5
    scrolled_win.add(textview)
    scrolled_win.set_policy(Gtk::POLICY_AUTOMATIC, Gtk::POLICY_ALWAYS)

    add(scrolled_win)
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
end
