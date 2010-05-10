#!/usr/bin/ruby

require 'gtk2'
require 'rubygems'
require 'git'
require 'pp'

BASE_DIR = File.expand_path(File.dirname(__FILE__))

require  BASE_DIR + '/libs/string'

class Gitruno < Gtk::Window
  @git = nil

  def initialize
    super

    puts "BASE_DIR = #{BASE_DIR}"
    @git = Git.init BASE_DIR + '/notes'
    puts "Git repo initialized!"
    puts ""

    set_title "Gitruno"
    signal_connect "destroy" do 
      puts "Closing!"
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
      puts "Added #{file} as '#{file.to_title}"
      num_notes = num_notes + 1
    end
    puts ">> #{num_notes} notes total."

    fixed.put notes_view, 0,0

    add fixed      
  end
end

Gtk.init
window = Gitruno.new
Gtk.main
