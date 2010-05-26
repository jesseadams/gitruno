class Gitruno < Gtk::Window
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
    tray_option_exit = Gtk::ImageMenuItem.new(Gtk::Stock::QUIT)

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
    @search_entry = Gtk::Entry.new

    @search_entry.signal_connect("changed") do
      puts "Trigger Search!"
      search
    end

    #@search.signal_connect("delete_text") do
    #  search
    #end

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

    table = Gtk::Table.new 9, 4, false
    table.set_column_spacings 3

    toolbar = Gtk::Toolbar.new
    toolbar.set_toolbar_style Gtk::Toolbar::Style::ICONS

    note_add = Gtk::ToolButton.new Gtk::Stock::NEW
    opentb = Gtk::ToolButton.new Gtk::Stock::OPEN
    savetb = Gtk::ToolButton.new Gtk::Stock::SAVE_AS
    delete = Gtk::ToolButton.new Gtk::Stock::STOP
    @sync_button = Gtk::ToolButton.new Gtk::Stock::REFRESH
    sep = Gtk::SeparatorToolItem.new
    info = Gtk::ToolButton.new Gtk::Stock::INFO
    close_button = Gtk::ToolButton.new Gtk::Stock::QUIT

    opentb.sensitive = false
    savetb.sensitive = false
    delete.sensitive = false

    toolbar.insert 0, note_add
    toolbar.insert 1, opentb
    toolbar.insert 2, savetb
    toolbar.insert 3, delete
    toolbar.insert 4, @sync_button
    toolbar.insert 5, sep
    toolbar.insert 6, info
    toolbar.insert 7, close_button

    note_add.signal_connect('clicked') do       
      note = Note.new
    end

    @sync_button.signal_connect('clicked') do
      if @sync_button.sensitive?
        sync
      end
    end
  
    info.signal_connect('clicked') do
      show_info
    end

    close_button.signal_connect('clicked') do
      destroy
    end

    table.attach(toolbar, 1, 4, 1, 2, Gtk::FILL, Gtk::FILL, 0, 0)
    table.attach(@search_entry, 1, 4, 2, 3, Gtk::FILL, Gtk::FILL, 5, 5)
    table.attach(scrolled_win, 1, 4, 3, 9, Gtk::FILL | Gtk::EXPAND, Gtk::FILL | Gtk::EXPAND, 1, 1)
    add table

    sort(0)

    @search_entry.grab_focus()
  end

  def load_notes
    puts ">> Loading notes... "
    files = Dir.entries(BASE_DIR + '/notes')

    num_notes = 0 
    files.each do |file|
      if ['.', '..', '.git'].include? file
        next
      end

      if @search_entry.text.length > 0
        unless file.downcase =~ /#{@search_entry.text.downcase}/
          next
        end
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

    dialog = Gtk::Dialog.new("Syncing Notes", self, Gtk::Dialog::DESTROY_WITH_PARENT)

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
      system('git pull origin master')

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
    while Gtk.events_pending? do
      #puts "Processing pending events..."
      Gtk.main_iteration
    end  
  end

  def search
    puts "Searching for notes: #{@search_entry.text}"
    @notes_model.clear
    load_notes
  end

  def show_info
    about = Gtk::AboutDialog.new
    about.set_program_name "Gitruno"
    about.set_version $VERSION
    about.set_copyright "Jesse R. Adams (techno-geek)"
    about.set_comments "A note application in ruby with git."
    about.set_website "http://github.com/techno-geek/gitruno"
    #about.set_logo Gtk::Stock::EDIT
    about.run
    about.destroy  
  end
end
