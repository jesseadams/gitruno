class Gitruno < Gtk::Window
  @git = nil
  @minimized = nil
  @notes_view = nil
  @notes_model = nil
  @notes_index = []
  @sync_button = nil

  @column_sort_id = nil
  @column_sort_direction = nil

  @title_column = nil
  @modified_column = nil

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
        self.deiconify
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
    
    @title_column = Gtk::TreeViewColumn.new("Title",
      Gtk::CellRendererText.new,
      :text => 0)
    @notes_view.append_column(@title_column)

    @title_column.clickable = true
    @title_column.signal_connect("clicked") do
      sort(0)
    end

    @modified_column = Gtk::TreeViewColumn.new("Last Modified",
      Gtk::CellRendererText.new,
      :text => 1)
    @notes_view.append_column(@modified_column)

    @modified_column.clickable = true
    @modified_column.signal_connect("clicked") do
      sort(1)
    end
    
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

    sort(0)
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

    # Create the dialog
    dialog = Gtk::Dialog.new("Syncing Notes", self, Gtk::Dialog::DESTROY_WITH_PARENT)

    # Ensure that the dialog box is destroyed when the user responds.
    dialog.signal_connect('response') { dialog.destroy }

    # Add the message in a label, and show everything we've added to the dialog.
    progress_text = Gtk::Label.new("Initializing...")

    progress_bar = Gtk::ProgressBar.new

    pulser = Gtk.timeout_add(100) do
      progress_bar.pulse
    end

    vbox = Gtk::VBox.new false, 10
    vbox.add(progress_text)
    vbox.add(progress_bar)

    dialog.vbox.add(vbox)

    dialog.set_default_size 250, 50

    dialog.show_all

    process_all_first

    Thread.start do
      if number_changed > 0
        puts "Files have changed. Committing before sync..."
        puts "Committing..."
        progress_text.text = 'Committing...'
        puts $git.commit_all('Syncing notes!')
      end
  
      puts "Pulling..."
      progress_text.text = 'Pulling in notes...'
      puts $git.pull

      print "Pushing... "
      progress_text.text = 'Pushing out notes...'
      $git.push
      print "OK\n"

      puts "Sync complete!"
      progress_text.text = 'Complete!'
    
      Gtk.timeout_remove(pulser)

      @sync_button.sensitive = true
      dialog.destroy
    end
  end

  def sort(column)
    direction = 'asc'
    if !@column_sort_id.nil? && @column_sort_id == column
      if @column_sort_direction == 'asc'
        direction = 'desc'
      else 
        direction = 'asc'
      end
    end

    case column
      when 0
        puts "Sorting by title #{direction}..."

        @title_column.sort_indicator = true
        if direction == 'asc'
          @title_column.sort_order = Gtk::SORT_ASCENDING
        else
          @title_column.sort_order = Gtk::SORT_DESCENDING
        end

        if @column_sort_id == 1
          @modified_column.sort_indicator = false
        end
      when 1
        puts "Sorting by mod time #{direction}..."

        @modified_column.sort_indicator = true
        if direction == 'asc'
          @modified_column.sort_order = Gtk::SORT_ASCENDING
        else
          @modified_column.sort_order = Gtk::SORT_DESCENDING
        end

        if @column_sort_id == 0
          @title_column.sort_indicator = false
        end
    end

    if direction == 'asc'
      @notes_model.set_sort_column_id column, Gtk::SORT_ASCENDING
    else
      @notes_model.set_sort_column_id column, Gtk::SORT_DESCENDING
    end

    @column_sort_id = column
    @column_sort_direction = direction
  end

  def process_all_first
    while (Gtk.events_pending?)
      puts "Processing pending events..."
      Gtk.main_iteration
    end  
  end
end
