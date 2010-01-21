#!/usr/bin/env ruby

require 'rubygems'
require 'rtf'

include RTF

colours = [Colour.new(0, 0, 0),
           Colour.new(255, 255, 255)]
           
# Create the used styles.
styles                           = {}
styles['EMPHASISED']             = CharacterStyle.new
styles['EMPHASISED'].bold        = true
styles['EMPHASISED'].underline   = true
styles['NORMAL']                 = ParagraphStyle.new
styles['NORMAL'].space_after     = 300

document = Document.new(Font.new(Font::ROMAN, 'Arial'))

document.paragraph(styles['NORMAL']) do |p|
   p << 'This document is a simple programmatically generated file that is '
   p << 'used to demonstrate table generation. A table containing 3 rows '
   p << 'and three columns should be displayed below this text.'
end

table    = document.table(3, 3, 2000, 4000, 2000)
table.border_width = 5
table[0][0] << 'Cell 0,0'
table[0][1].top_border_width = 10
table[0][1] << 'This is a little preamble text for '
table[0][1].apply(styles['EMPHASISED']) << 'Cell 0,1'
table[0][1].line_break
table[0][1] << ' to help in examining how formatting is working.'
table[0][2] << 'Cell 0,2'
table[1][0] << 'Cell 1,0'
table[1][1] << 'Cell 1,1'
table[1][2] << 'Cell 1,2'
table[2][0] << 'Cell 2,0'
table[2][1] << 'Cell 2,1'
table[2][2] << 'Cell 2,2'

File.open('example02.rtf', 'w') do |file|
   file.write(document.to_rtf)
end