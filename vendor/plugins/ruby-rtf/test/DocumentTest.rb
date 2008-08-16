#!/usr/bin/env ruby

require 'rubygems'
require 'test/unit'
require 'rtf'

include RTF

# Information class unit test class.
class DocumentTest < Test::Unit::TestCase
   def setup
      @fonts = FontTable.new

      @fonts << Font.new(Font::ROMAN, 'Arial')
      @fonts << Font.new(Font::MODERN, 'Courier')
   end

   def test_basics
      documents = []
      style     = DocumentStyle.new

      documents << Document.new(@fonts[0])
      documents << Document.new(@fonts[1], style)
      documents << Document.new(@fonts[0], nil, Document::CS_MAC)
      documents << Document.new(@fonts[1], style, Document::CS_PC,
                                Document::LC_ENGLISH_US)

      lr_margin = DocumentStyle::DEFAULT_LEFT_MARGIN +
                  DocumentStyle::DEFAULT_RIGHT_MARGIN
      tb_margin = DocumentStyle::DEFAULT_TOP_MARGIN +
                  DocumentStyle::DEFAULT_BOTTOM_MARGIN

      fonts     = []
      fonts << FontTable.new(@fonts[0])
      fonts << FontTable.new(@fonts[1])

      assert(documents[0].character_set == Document::CS_ANSI)
      assert(documents[1].character_set == Document::CS_ANSI)
      assert(documents[2].character_set == Document::CS_MAC)
      assert(documents[3].character_set == Document::CS_PC)

      assert(documents[0].fonts.size == 1)
      assert(documents[1].fonts.size == 1)
      assert(documents[2].fonts.size == 1)
      assert(documents[3].fonts.size == 1)

      assert(documents[0].fonts[0] == @fonts[0])
      assert(documents[1].fonts[0] == @fonts[1])
      assert(documents[2].fonts[0] == @fonts[0])
      assert(documents[3].fonts[0] == @fonts[1])

      assert(documents[0].colours.size == 0)
      assert(documents[1].colours.size == 0)
      assert(documents[2].colours.size == 0)
      assert(documents[3].colours.size == 0)

      assert(documents[0].language == Document::LC_ENGLISH_UK)
      assert(documents[1].language == Document::LC_ENGLISH_UK)
      assert(documents[2].language == Document::LC_ENGLISH_UK)
      assert(documents[3].language == Document::LC_ENGLISH_US)

      assert(documents[0].style != nil)
      assert(documents[1].style == style)
      assert(documents[2].style != nil)
      assert(documents[3].style == style)

      assert(documents[0].body_width == Paper::A4.width - lr_margin)
      assert(documents[0].body_height == Paper::A4.height - tb_margin)
      assert(documents[0].default_font == @fonts[0])
      assert(documents[0].paper == Paper::A4)
      assert(documents[0].header == nil)
      assert(documents[0].header(HeaderNode::UNIVERSAL) == nil)
      assert(documents[0].header(HeaderNode::LEFT_PAGE) == nil)
      assert(documents[0].header(HeaderNode::RIGHT_PAGE) == nil)
      assert(documents[0].header(HeaderNode::FIRST_PAGE) == nil)
      assert(documents[0].footer == nil)
      assert(documents[0].footer(FooterNode::UNIVERSAL) == nil)
      assert(documents[0].footer(FooterNode::LEFT_PAGE) == nil)
      assert(documents[0].footer(FooterNode::RIGHT_PAGE) == nil)
      assert(documents[0].footer(FooterNode::FIRST_PAGE) == nil)
   end

   def test_mutators
      document = Document.new(@fonts[0])

      document.default_font = @fonts[1]
      assert(document.default_font == @fonts[1])

      document.character_set = Document::CS_PCA
      assert(document.character_set == Document::CS_PCA)

      document.language = Document::LC_CZECH
      assert(document.language == Document::LC_CZECH)
   end

   def test_page_break
      document = Document.new(@fonts[0])

      assert(document.page_break == nil)
      assert(document.size == 1)
      assert(document[0].prefix == '\page')
   end

   def test_exceptions
      document = Document.new(@fonts[0])
      begin
         document.parent = document
         flunk("Successfully change the parent of a Document object.")
      rescue
      end
   end
end
