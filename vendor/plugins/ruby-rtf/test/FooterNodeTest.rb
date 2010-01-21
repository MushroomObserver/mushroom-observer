#!/usr/bin/env ruby

require 'rubygems'
require 'test/unit'
require 'rtf'

include RTF

# Information class unit test class.
class FooterNodeTest < Test::Unit::TestCase
   def setup
      @document = Document.new(Font.new(Font::ROMAN, 'Arial'))
   end

   def test_basics
      footers = []

      footers << FooterNode.new(@document)
      footers << FooterNode.new(@document, FooterNode::LEFT_PAGE)

      assert(footers[0].parent == @document)
      assert(footers[1].parent == @document)

      assert(footers[0].type == FooterNode::UNIVERSAL)
      assert(footers[1].type == FooterNode::LEFT_PAGE)
   end

   def test_exceptions
      footer = FooterNode.new(@document)
      begin
         footer.footnote("La la la.")
         flunk("Successfully added a footnote to a footer.")
      rescue
      end
   end
end
