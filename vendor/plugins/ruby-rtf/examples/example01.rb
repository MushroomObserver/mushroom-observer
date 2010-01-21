#!/usr/bin/env ruby

require 'rubygems'
require 'rtf'

include RTF

# Create required styles.
styles = {}
styles['HEADER'] = CharacterStyle.new
styles['HEADER'].bold      = true
styles['HEADER'].font_size = 28
styles['NORMAL'] = ParagraphStyle.new
styles['NORMAL'].justification = ParagraphStyle::FULL_JUSTIFY
styles['INDENTED'] = ParagraphStyle.new
styles['INDENTED'].left_indent = 400

document = Document.new(Font.new(Font::ROMAN, 'Arial'))
document.paragraph do |p|
   p.apply(styles['HEADER']) do |s|
      s << '1.0 Introduction'
   end
end
document.paragraph(styles['NORMAL']) do |p|
   p << 'Here is a short example program in the Ruby programming '
   p << 'language that demonstrates writing a single line of text '
   p << 'to a file created in the current working directory...'
end

c = 1
document.paragraph(styles['INDENTED']) do |n1|
   n1.line_break
   n1.font(Font.new(Font::MODERN, 'Courier New')) do |n2|
      n2 << "#{sprintf('%02d', c)}   File.open('output.txt', 'w') do |file|"
      c += 1
      n2.line_break
      n2 << "#{sprintf('%02d', c)}      file.write('Some text.')"
      c += 1
      n2.line_break
      n2 << "#{sprintf('%02d', c)}   end"
   end
end

document.line_break
document.paragraph(styles['NORMAL']) do |p|
   p << "And there you have it. A simple example indeed."
end

File.open('example01.rtf', 'w') do |file|
   file.write(document.to_rtf)
end