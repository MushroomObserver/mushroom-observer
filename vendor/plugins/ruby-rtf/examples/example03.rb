#!/usr/bin/env ruby

require 'rubygems'
require 'rtf'

include RTF

fonts = [Font.new(Font::ROMAN, 'Times New Roman'),
         Font.new(Font::MODERN, 'Courier')]

styles = {}
styles['PS_HEADING']              = ParagraphStyle.new
styles['PS_NORMAL']               = ParagraphStyle.new
styles['PS_NORMAL'].justification = ParagraphStyle::FULL_JUSTIFY
styles['PS_INDENTED']             = ParagraphStyle.new
styles['PS_INDENTED'].left_indent = 300
styles['PS_TITLE']                = ParagraphStyle.new
styles['PS_TITLE'].space_before   = 100
styles['PS_TITLE'].space_after    = 200
styles['CS_HEADING']              = CharacterStyle.new
styles['CS_HEADING'].bold         = true
styles['CS_HEADING'].font_size    = 36
styles['CS_CODE']                 = CharacterStyle.new
styles['CS_CODE'].font            = fonts[1]
styles['CS_CODE'].font_size       = 16

document = Document.new(fonts[0])

document.paragraph(styles['PS_HEADING']) do |p1|
   p1.apply(styles['CS_HEADING']) << 'Example Program'
end

document.paragraph(styles['PS_NORMAL']) do |p1|
   p1 << 'This document is automatically generated using the RTF Ruby '
   p1 << 'library by Peter Wood. This serves as an example of what can '
   p1 << 'be achieved in document creation via the library. The source '
   p1 << 'code that was used to generate it is listed below...'
end

document.paragraph(styles['PS_INDENTED']) do |p1|
   n = 1
   p1.apply(styles['CS_CODE']) do |p2|
      File.open('example03.rb') do |file|
         file.each_line do |line|
            p2.line_break
            p2 << "#{n > 9 ? '' : ' '}#{n}   #{line.chomp}"
            n += 1
         end
      end
   end
end

document.paragraph(styles['PS_TITLE']) do |p1|
   p1.italic do |p2|
      p2.bold << 'Listing 1:'
      p2 << ' Generator program code listing.'
   end
end

document.paragraph(styles['PS_NORMAL']) do |p1|
   p1 << "This example shows the creation of a new document and the "
   p1 << "of textual content to it. The example also provides examples "
   p1 << "of using block scope to delimit style scope (lines 35-40)."
end

File.open('example03.rtf', 'w') {|file| file.write(document.to_rtf)}