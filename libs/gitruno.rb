class Gitruno < Gtk::Window
  @git = nil
  @minimized = nil

  def initialize
    super

    @minimized = true

    set_title "Gitruno"
    signal_connect "destroy" do 
      puts "Closing!"
      Gtk.main_quit 
    end
      
    init_ui
      
    set_default_size 400, 400
    set_window_position Gtk::Window::POS_CENTER

    icon = Gtk::StatusIcon.new
    icon.tooltip = 'Gitruno'
    icon.set_stock Gtk::Stock::EDIT

    icon.signal_connect('activate') do
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

  end

  def init_ui
    fixed = Gtk::Fixed.new

    notes_model = Gtk::ListStore.new(String, String)
    notes_view = Gtk::TreeView.new(notes_model)
    
    title_column = Gtk::TreeViewColumn.new("Title",
      Gtk::CellRendererText.new,
      :text => 0)
    notes_view.append_column(title_column)
    modified_column = Gtk::TreeViewColumn.new("Last Modified",
      Gtk::CellRendererText.new,
      :text => 1)
    notes_view.append_column(modified_column)
    
    notes_view.selection.set_mode(Gtk::SELECTION_SINGLE)

    puts ">> Loading notes... "
    files = Dir.entries(BASE_DIR + '/notes')
  
    num_notes = 0
    files.each do |file|
      if ['.', '..', '.git'].include? file
        next
      end

      iter = notes_model.append
      iter[0] = file.to_title
      iter[1] = File.mtime(BASE_DIR + '/notes/' + file).to_s
      puts "Added #{file} as '#{file.to_title}'"
      num_notes = num_notes + 1
    end
    puts ">> #{num_notes} notes total."

    notes_view.signal_connect("row-activated") do |view, path, column|
      puts "Row #{path.to_str} was clicked!"

      if iter = view.model.get_iter(path)
        puts "Double-clicked row contains name #{iter[0]}!"
        note = Note.new iter[0].to_filename
      end
    end

    fixed.put notes_view, 0,0

    add fixed      
  end
end
