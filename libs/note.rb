CRYPTO_KEY = '047afed631b2227ee276a6e91325394a'

class Note < Gtk::Window
  @note = nil
  @buffer = nil
  @file = nil
  @deleted = false
  @title = nil
  @encode_note = false
  @was_encoded = false

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

        if @note != @buffer.text or @was_encoded != @encode_note
          puts "Saving Note: #{note}"
          save_note(note)
          $window.reload_notes

          puts Dir.getwd()
          system('git add .')
          system("git commit -a -m \"Saved note #{note}\"")
          puts "Note saved: #{note}"
        elsif @renamed
          $window.reload_notes
        end
      rescue Exception => error
        puts error.message
      end

      if @rename_window_open
        @rename.destroy
      end
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
    
    encode_not_clicked = Gtk::Stock::SAVE
    encode_clicked = Gtk::Stock::SAVE_AS

    if @was_encoded then
      @encode_button = Gtk::ToolButton.new encode_clicked
      @encode_note = true
    else
      @encode_button = Gtk::ToolButton.new encode_not_clicked
    end

    toolbar.insert 0, rename_button
    toolbar.insert 1, delete_button
    toolbar.insert 2, @encode_button
    
    if @note.nil?
      delete_button.sensitive = false
      rename_button.sensitive = false
    end

    unless !delete_button.sensitive?
      delete_button.signal_connect('clicked') do
        delete_note
      end
    end

    unless !rename_button.sensitive?
      rename_button.signal_connect('clicked') do
        rename_note
      end
    end

    @encode_button.signal_connect('clicked') do
      if @encode_button.stock_id == encode_not_clicked.to_s then
        puts "encode that note!"
        @encode_note = true
        @encode_button.stock_id = encode_clicked
      else
        puts "dont encode that note!"
        @encode_note = false
        @encode_button.stock_id = encode_not_clicked
      end
      puts "pass"
    end

    table.attach(toolbar, 1, 4, 1, 2, Gtk::FILL, Gtk::FILL, 0, 0)
    table.attach(scrolled_win, 1, 4, 3, 8, Gtk::FILL | Gtk::EXPAND, Gtk::FILL | Gtk::EXPAND, 1, 1)
    add table 

    textview.grab_focus()
  end

  def file_to_string(file)
    lines = File.readlines(NOTE_DIR + '/' + file)

    if lines.first.chomp == "encoding=true" then
      @was_encoded = true
      contents = ''
      lines.each do |line|
        next if line == lines.first
        contents << line
      end
   
      return Blowfish.decrypt(CRYPTO_KEY, contents.chomp)
    else
      return lines.join("")
    end
  end

  def save_note(file)
    handle = File.open(NOTE_DIR + '/' + file, 'w')

    if @encode_note then
      handle.puts "encoding=true"
      handle.puts Blowfish.encrypt(CRYPTO_KEY, @buffer.text)
    else
      lines = @buffer.text.split("\n")

      lines.each do |line|
        handle.puts line
      end
    end

    handle.close
  end 

  def delete_note
    print "Deleting #{@file}... "
    #$git.remove(NOTE_DIR + '/' + @file)
    system("git rm #{File.join(NOTE_DIR, @file)}")
    #$git.commit_all("Removed note #{@file}")
    system("git commit -a -m \"Removed note #{@file}\"")
    print "OK\n"
     
    @deleted = true
    $window.reload_notes
    destroy
  end

  def rename_note
    unless @rename_window_open
      vbox = Gtk::VBox.new 5, 5

      @rename_entry = Gtk::Entry.new
      @rename_entry.text = @title

      @rename_button = Gtk::Button.new("OK")
      @rename_button.signal_connect('clicked') do
        if @title == @rename_entry.text
          puts "Title did not change!"
        elsif @rename_entry.text.length > 0
          FileUtils.cp @title.to_filename, @rename_entry.text.to_filename
          system("git rm #{@title.to_filename}")
          system("git add .")
          system("git commit -a -m \"Renamed #{@title.to_filename} to #{@rename_entry.text.to_filename}\"")

          puts "Renamed #{@title.to_filename} to #{@rename_entry.text.to_filename}"

          @title = @rename_entry.text
          @renamed = true
        end

        @rename.destroy
      end

      @rename = Gtk::Window.new
      @rename.set_title "Rename Note"
      @rename.set_default_size 300, 100
      
      vbox.add(Gtk::Label.new("Enter new name"))
      vbox.add(@rename_entry)

      hbox = Gtk::HBox.new 5, 5
      hbox.add(Gtk::Label.new(""))
      hbox.add(@rename_button)

      vbox.add(hbox)

      @rename.add(vbox)

      @rename.signal_connect('destroy') do
        @rename_window_open = false
      end

      @rename.show_all
    end

    @rename.present
    @rename_window_open = true
  end
end
