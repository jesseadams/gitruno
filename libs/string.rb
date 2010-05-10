class String
  def to_filename
    string = self.gsub(/ /, '_')
    string = string.gsub(/[\'!@#$\%^&*]/, '')
    string.downcase
  end

  def to_title
    string = self.gsub(/_/, ' ')
    string.gsub(/(\w+)/) {|s| s.capitalize}
  end
end
