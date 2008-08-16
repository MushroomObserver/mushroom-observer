#!/usr/bin/env ruby

require 'rubygems'
require 'test/unit'
require 'rtf'

include RTF

# Information class unit test class.
class StyleTest < Test::Unit::TestCase
   def test_basics
      style = Style.new

      assert(style.is_character_style? == false)
      assert(style.is_document_style? == false)
      assert(style.is_paragraph_style? == false)
      assert(style.is_table_style? == false)

      assert(style.prefix(nil, nil) == nil)
      assert(style.suffix(nil, nil) == nil)
   end
end
