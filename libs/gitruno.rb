class Gitruno < Gtk::Window
  @git = nil
  @minimized = nil
  @notes_view = nil
  @notes_model = nil
  @notes_index = []
  @sync_button = nil

  def initialize
    super

    @minimized = true
    @can_sync = true

    set_title "Gitruno"
    signal_connect "destroy" do 
      puts "Closing!"
      Gtk.main_quit 
    end
      
    init_ui
      
    set_default_size 450, 450
    set_window_position Gtk::Window::POS_CENTER

    icon = render_icon(Gtk::Stock::EDIT, Gtk::IconSize::DIALOG)
    set_icon(icon)

    tray_icon = Gtk::StatusIcon.new
    tray_icon.tooltip = 'Gitruno'
    tray_icon.set_stock Gtk::Stock::EDIT

    tray_icon.signal_connect('activate') do
      if @minimized
        puts "Showing window..."
        self.show_all
        @minimized = false
      else
        puts "Hiding window..."
        self.hide
        @minimized = true
      end
    end

    tray_option_sync = Gtk::MenuItem.new("Sync")
    tray_option_exit = Gtk::MenuItem.new("Exit")

    tray_option_sync.signal_connect('activate') do
      sync
    end
    tray_option_exit.signal_connect('activate') do
      destroy
    end

    tray_menu = Gtk::Menu.new
    tray_menu.append(tray_option_sync)
    tray_menu.append(tray_option_exit)
    tray_menu.show_all

    tray_icon.position_menu(tray_menu)

    tray_icon.signal_connect('popup-menu') do |tray, button, time|
      tray_menu.popup nil, nil, button, time
    end
  end

  def init_ui
    @notes_model = Gtk::ListStore.new(String, String)
    @notes_view = Gtk::TreeView.new(@notes_model)
    
    title_column = Gtk::TreeViewColumn.new("Title",
      Gtk::CellRendererText.new,
      :text => 0)
    @notes_view.append_column(title_column)
    modified_column = Gtk::TreeViewColumn.new("Last Modified",
      Gtk::CellRendererText.new,
      :text => 1)
    @notes_view.append_column(modified_column)
    
    @notes_view.selection.set_mode(Gtk::SELECTION_SINGLE)

    load_notes

    @notes_view.signal_connect("row-activated") do |view, path, column|
      puts "Row #{path.to_str} was clicked!"

      if iter = view.model.get_iter(path)
        puts "Double-clicked row contains name #{iter[0]}!"
        note = Note.new iter[0].to_filename
      end
    end

    scrolled_win = Gtk::ScrolledWindow.new
    scrolled_win.border_width = 5
    scrolled_win.add(@notes_view)
    scrolled_win.set_policy(Gtk::POLICY_AUTOMATIC, Gtk::POLICY_ALWAYS)

    new_note_button = Gtk::Button.new('New')

    @sync_button = Gtk::Button.new('Sync')

    new_note_button.signal_connect('clicked') do 
      note = Note.new
    end

    @sync_button.signal_connect('clicked') do 
      if @sync_button.sensitive?
        sync
      end
    end

    table = Gtk::Table.new 8, 4, false
    table.set_column_spacings 3

    table.attach(scrolled_win, 1, 4, 1, 6, Gtk::FILL | Gtk::EXPAND, Gtk::FILL | Gtk::EXPAND, 1, 1)
    table.attach(new_note_button, 1, 2, 7, 8, Gtk::FILL, Gtk::FILL, 5, 5)
    table.attach(@sync_button, 3, 4, 7, 8, Gtk::FILL, Gtk::FILL, 5, 5)
    add table
    # FIXME: http://zetcode.com/tutorials/rubygtktutorial/layoutmanagement/
  end

  def load_notes
    puts ">> Loading notes... "
    files = Dir.entries(BASE_DIR + '/notes')

    num_notes = 0
    files.each do |file|
      if ['.', '..', '.git'].include? file
        next
      end

      iter = @notes_model.append
      iter[0] = file.to_title
      iter[1] = Time.parse(File.mtime(BASE_DIR + '/notes/' + file).to_s).strftime('%Y-%m-%d %I:%M %p')
      puts "Added #{file} as '#{file.to_title}'"
      num_notes = num_notes + 1
    end
    puts ">> #{num_notes} notes total."    
  end

  def reload_notes
    puts "Removing current notes in list..."
    @notes_model.clear

    load_notes
  end

  def sync
    @sync_button.sensitive = false
    puts "Attempting to sync files..."
    number_changed = $git.status.changed.length
  
    if number_changed > 0
      puts "Files have changed. Committing before sync..."
      puts "Committing..."
      puts $git.commit_all('Syncing notes!')
    end
  
    puts "Pulling..."
    puts $git.pull

    print "Pushing... "
    $git.push
    print "OK\n"

    puts "Sync complete!"
    
    @sync_button.sensitive = true
  end
end
