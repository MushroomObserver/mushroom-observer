#!/usr/bin/env ruby

require 'rubygems'
require 'test/unit'
require 'rtf'

include RTF

# Information class unit test class.
class DocumentStyleTest < Test::Unit::TestCase
   def test_basics
      style = DocumentStyle.new

      assert(style.is_character_style? == false)
      assert(style.is_document_style? == true)
      assert(style.is_paragraph_style? == false)
      assert(style.is_table_style? == false)

      assert(style.prefix(nil, nil) == '\paperw11907\paperh16840\margl1800'\
                                       '\margr1800\margt1440\margb1440')
      assert(style.suffix(nil, nil) == nil)

      assert(style.bottom_margin == DocumentStyle::DEFAULT_BOTTOM_MARGIN)
      assert(style.gutter == nil)
      assert(style.left_margin == DocumentStyle::DEFAULT_LEFT_MARGIN)
      assert(style.orientation == DocumentStyle::PORTRAIT)
      assert(style.paper == Paper::A4)
      assert(style.right_margin == DocumentStyle::DEFAULT_RIGHT_MARGIN)
      assert(style.top_margin == DocumentStyle::DEFAULT_TOP_MARGIN)
   end

  def test_mutators
     style = DocumentStyle.new

     style.bottom_margin = 200
     assert(style.bottom_margin == 200)

     style.gutter = 1000
     assert(style.gutter == 1000)

     style.left_margin = 34
     assert(style.left_margin == 34)

     style.orientation = DocumentStyle::LANDSCAPE
     assert(style.orientation == DocumentStyle::LANDSCAPE)

     style.paper = Paper::LETTER
     assert(style.paper == Paper::LETTER)

     style.right_margin = 345
     assert(style.right_margin == 345)

     style.top_margin = 819
     assert(style.top_margin == 819)
  end

  def test_prefix
     style   = DocumentStyle.new

     style.left_margin = style.right_margin = 200
     style.top_margin  = style.bottom_margin = 100
     style.gutter      = 300
     style.orientation = DocumentStyle::LANDSCAPE
     style.paper       = Paper::A5

     assert(style.prefix(nil, nil) == '\paperw11907\paperh8392\margl200'\
                                      '\margr200\margt100\margb100\gutter300'\
                                      '\sectd\lndscpsxn')
  end

  def test_body_method
     style = DocumentStyle.new

     lr_margin = style.left_margin + style.right_margin
     tb_margin = style.top_margin + style.bottom_margin

     assert(style.body_width == Paper::A4.width - lr_margin)
     assert(style.body_height == Paper::A4.height - tb_margin)

     style.orientation = DocumentStyle::LANDSCAPE

     assert(style.body_width == Paper::A4.height - lr_margin)
     assert(style.body_height == Paper::A4.width - tb_margin)
  end
end
