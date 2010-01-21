#!/usr/bin/env ruby

require 'rubygems'
require 'test/unit'
require 'rtf'

include RTF

# Information class unit test class.
class ParagraphStyleTest < Test::Unit::TestCase
   def test_basics
      style = ParagraphStyle.new

      assert(style.is_character_style? == false)
      assert(style.is_document_style? == false)
      assert(style.is_paragraph_style? == true)
      assert(style.is_table_style? == false)

      assert(style.prefix(nil, nil) == '\ql')
      assert(style.suffix(nil, nil) == nil)

      assert(style.first_line_indent == nil)
      assert(style.flow == ParagraphStyle::LEFT_TO_RIGHT)
      assert(style.justification == ParagraphStyle::LEFT_JUSTIFY)
      assert(style.left_indent == nil)
      assert(style.right_indent == nil)
      assert(style.line_spacing == nil)
      assert(style.space_after == nil)
      assert(style.space_before == nil)
   end

  def test_mutators
     style = ParagraphStyle.new

     style.first_line_indent = 100
     assert(style.first_line_indent == 100)

     style.flow = ParagraphStyle::RIGHT_TO_LEFT
     assert(style.flow == ParagraphStyle::RIGHT_TO_LEFT)

     style.justification = ParagraphStyle::RIGHT_JUSTIFY
     assert(style.justification == ParagraphStyle::RIGHT_JUSTIFY)

     style.left_indent = 234
     assert(style.left_indent == 234)

     style.right_indent = 1020
     assert(style.right_indent == 1020)

     style.line_spacing = 645
     assert(style.line_spacing == 645)

     style.space_after = 25
     assert(style.space_after == 25)

     style.space_before = 918
     assert(style.space_before == 918)
  end

  def test_prefix
     style   = ParagraphStyle.new

     style.first_line_indent = 100
     assert(style.prefix(nil, nil) == '\ql\fi100')

     style.flow = ParagraphStyle::RIGHT_TO_LEFT
     assert(style.prefix(nil, nil) == '\ql\fi100\rtlpar')

     style.justification = ParagraphStyle::RIGHT_JUSTIFY
     assert(style.prefix(nil, nil) == '\qr\fi100\rtlpar')

     style.left_indent = 234
     assert(style.prefix(nil, nil) == '\qr\li234\fi100\rtlpar')

     style.right_indent = 1020
     assert(style.prefix(nil, nil) == '\qr\li234\ri1020\fi100\rtlpar')

     style.line_spacing = 645
     assert(style.prefix(nil, nil) == '\qr\li234\ri1020\fi100\sl645\rtlpar')

     style.space_after = 25
     assert(style.prefix(nil, nil) == '\qr\li234\ri1020\fi100\sa25\sl645\rtlpar')

     style.space_before = 918
     assert(style.prefix(nil, nil) == '\qr\li234\ri1020\fi100\sb918\sa25\sl645\rtlpar')
  end
end
