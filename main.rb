#!/usr/bin/ruby

require 'gtk2'
require 'rubygems'
require 'git'
require 'date'

require 'libs/string'

class Gitruno < Gtk::Window
  def initialize
    super

    set_title "Gitruno"
    signal_connect "destroy" do 
      Gtk.main_quit 
    end
      
    init_ui
      
    set_default_size 400, 400
    set_window_position Gtk::Window::POS_CENTER
    show_all
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

    files = Dir.entries('notes')
    files.each do |file|
      if ['.', '..'].include? file
        next
      end

      iter = notes_model.append
      iter[0] = file.to_title
      iter[1] = File.mtime('notes/' + file).to_s
    end

    fixed.put notes_view, 0,0

    add fixed      
  end
end

Gtk.init
    window = Gitruno.new
Gtk.main
