#!/usr/bin/env ruby

require 'rubygems'
require 'test/unit'
require 'rtf'

include RTF

# Information class unit test class.
class CharacterStyleTest < Test::Unit::TestCase
   def test_basics
      style = CharacterStyle.new

      assert(style.is_character_style? == true)
      assert(style.is_document_style? == false)
      assert(style.is_paragraph_style? == false)
      assert(style.is_table_style? == false)

      assert(style.prefix(nil, nil) == nil)
      assert(style.suffix(nil, nil) == nil)

      assert(style.background == nil)
      assert(style.bold == false)
      assert(style.capitalise == false)
      assert(style.flow == CharacterStyle::LEFT_TO_RIGHT)
      assert(style.font == nil)
      assert(style.font_size == nil)
      assert(style.foreground == nil)
      assert(style.hidden == false)
      assert(style.italic == false)
      assert(style.strike == false)
      assert(style.subscript == false)
      assert(style.superscript == false)
      assert(style.underline == false)
   end

  def test_mutators
     style = CharacterStyle.new

     style.background = Colour.new(100, 100, 100)
     assert(style.background == Colour.new(100, 100, 100))

     style.bold = true
     assert(style.bold)

     style.capitalise = true
     assert(style.capitalize)

     style.flow = CharacterStyle::RIGHT_TO_LEFT
     assert(style.flow == CharacterStyle::RIGHT_TO_LEFT)

     style.font = Font.new(Font::ROMAN, 'Arial')
     assert(style.font == Font.new(Font::ROMAN, 'Arial'))

     style.font_size = 38
     assert(style.font_size == 38)

     style.foreground = Colour.new(250, 200, 150)
     assert(style.foreground == Colour.new(250, 200, 150))

     style.hidden = true
     assert(style.hidden)

     style.italic = true
     assert(style.italic)

     style.strike = true
     assert(style.strike)

     style.subscript = true
     assert(style.subscript)

     style.superscript = true
     assert(style.superscript)

     style.underline = true
     assert(style.underline)
  end

  def test_prefix
     fonts   = FontTable.new(Font.new(Font::ROMAN, 'Arial'))
     colours = ColourTable.new(Colour.new(100, 100, 100))
     style   = CharacterStyle.new

     style.background = colours[0]
     assert(style.prefix(fonts, colours) == '\cb1')

     style.background = nil
     style.bold       = true
     assert(style.prefix(nil, nil) == '\b')

     style.bold       = false
     style.capitalise = true
     assert(style.prefix(nil, nil) == '\caps')

     style.capitalize = false
     style.flow       = CharacterStyle::RIGHT_TO_LEFT
     assert(style.prefix(nil, nil) == '\rtlch')

     style.flow = nil
     style.font = fonts[0]
     assert(style.prefix(fonts, colours) == '\f0')

     style.font      = nil
     style.font_size = 40
     assert(style.prefix(nil, nil) == '\fs40')

     style.font_size  = nil
     style.foreground = colours[0]
     assert(style.prefix(fonts, colours) == '\cf1')

     style.foreground = nil
     style.hidden     = true
     assert(style.prefix(nil, nil) == '\v')

     style.hidden = false
     style.italic = true
     assert(style.prefix(nil, nil) == '\i')

     style.italic = false
     style.strike = true
     assert(style.prefix(nil, nil) == '\strike')

     style.strike    = false
     style.subscript = true
     assert(style.prefix(nil, nil) == '\sub')

     style.subscript   = false
     style.superscript = true
     assert(style.prefix(fonts, colours) == '\super')

     style.superscript = false
     style.underline   = true
     assert(style.prefix(fonts, colours) == '\ul')

     style.flow       = CharacterStyle::RIGHT_TO_LEFT
     style.background = colours[0]
     style.font_size  = 18
     style.subscript  = true
     assert(style.prefix(fonts, colours) == '\ul\sub\cb1\fs18\rtlch')
  end
end
