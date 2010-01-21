#!/usr/bin/env ruby

require 'rubygems'
require 'test/unit'
require 'rtf'

include RTF

# Information class unit test class.
class TableNodeTest < Test::Unit::TestCase
   def setup
      @document = Document.new(Font.new(Font::ROMAN, 'Times New Roman'))
      @colours  = []

      @colours << Colour.new(200, 200, 200)
      @colours << Colour.new(200, 0, 0)
      @colours << Colour.new(0, 200, 0)
      @colours << Colour.new(0, 0, 200)
   end

   def test_basics
      table = TableNode.new(@document, 3, 5, 10, 20, 30, 40, 50)

      assert(table.rows == 3)
      assert(table.columns == 5)
      assert(table.size == 3)
      assert(table.cell_margin == 100)
   end

   def test_mutators
      table = TableNode.new(@document, 3, 3)

      table.cell_margin = 250
      assert(table.cell_margin == 250)
   end

   def test_colouring
      table = TableNode.new(@document, 3, 3)

      table.row_shading_colour(1, @colours[0])
      assert(table[0][0].shading_colour == nil)
      assert(table[0][1].shading_colour == nil)
      assert(table[0][2].shading_colour == nil)
      assert(table[1][0].shading_colour == @colours[0])
      assert(table[1][1].shading_colour == @colours[0])
      assert(table[1][2].shading_colour == @colours[0])
      assert(table[2][0].shading_colour == nil)
      assert(table[2][1].shading_colour == nil)
      assert(table[2][2].shading_colour == nil)

      table.column_shading_colour(2, @colours[1])
      assert(table[0][0].shading_colour == nil)
      assert(table[0][1].shading_colour == nil)
      assert(table[0][2].shading_colour == @colours[1])
      assert(table[1][0].shading_colour == @colours[0])
      assert(table[1][1].shading_colour == @colours[0])
      assert(table[1][2].shading_colour == @colours[1])
      assert(table[2][0].shading_colour == nil)
      assert(table[2][1].shading_colour == nil)
      assert(table[2][2].shading_colour == @colours[1])

      table.shading_colour(@colours[2]) {|cell, x, y| x == y}
      assert(table[0][0].shading_colour == @colours[2])
      assert(table[0][1].shading_colour == nil)
      assert(table[0][2].shading_colour == @colours[1])
      assert(table[1][0].shading_colour == @colours[0])
      assert(table[1][1].shading_colour == @colours[2])
      assert(table[1][2].shading_colour == @colours[1])
      assert(table[2][0].shading_colour == nil)
      assert(table[2][1].shading_colour == nil)
      assert(table[2][2].shading_colour == @colours[2])
   end

   def test_border_width
      table = TableNode.new(@document, 2, 2)

      table.border_width = 5
      assert(table[0][0].border_widths == [5, 5, 5, 5])
      assert(table[0][1].border_widths == [5, 5, 5, 5])
      assert(table[1][0].border_widths == [5, 5, 5, 5])
      assert(table[1][1].border_widths == [5, 5, 5, 5])

      table.border_width = 0
      assert(table[0][0].border_widths == [0, 0, 0, 0])
      assert(table[0][1].border_widths == [0, 0, 0, 0])
      assert(table[1][0].border_widths == [0, 0, 0, 0])
      assert(table[1][1].border_widths == [0, 0, 0, 0])
   end
end
