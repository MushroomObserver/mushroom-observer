#!/usr/bin/env ruby

require 'rubygems'
require 'test/unit'
require 'rtf'

include RTF

# Information class unit test class.
class HeaderNodeTest < Test::Unit::TestCase
   def setup
      @document = Document.new(Font.new(Font::ROMAN, 'Arial'))
   end

   def test_basics
      headers = []

      headers << HeaderNode.new(@document)
      headers << HeaderNode.new(@document, HeaderNode::LEFT_PAGE)

      assert(headers[0].parent == @document)
      assert(headers[1].parent == @document)

      assert(headers[0].type == HeaderNode::UNIVERSAL)
      assert(headers[1].type == HeaderNode::LEFT_PAGE)
   end

   def test_exceptions
      headers = HeaderNode.new(@document)
      begin
         headers.footnote("La la la.")
         flunk("Successfully added a footnote to a header.")
      rescue
      end
   end
end
