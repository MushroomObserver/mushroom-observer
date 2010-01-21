#!/usr/bin/env ruby

require 'rubygems'
require 'test/unit'
require 'rtf'

include RTF

# Information class unit test class.
class TableCellNodeTest < Test::Unit::TestCase
   def setup
      @table = TableNode.new(nil, 3, 3, 100, 100, 100)
      @row   = TableRowNode.new(@table, 3, 100)
   end

   def test_basics
      cells = []
      cells.push(TableCellNode.new(@row))
      cells.push(TableCellNode.new(@row, 1000))
      cells.push(TableCellNode.new(@row, 250, nil, 5, 10, 15, 20))

      assert(cells[0].parent == @row)
      assert(cells[0].width == TableCellNode::DEFAULT_WIDTH)
      assert(cells[0].top_border_width == 0)
      assert(cells[0].right_border_width == 0)
      assert(cells[0].bottom_border_width == 0)
      assert(cells[0].left_border_width == 0)

      assert(cells[1].parent == @row)
      assert(cells[1].width == 1000)
      assert(cells[1].top_border_width == 0)
      assert(cells[1].right_border_width == 0)
      assert(cells[1].bottom_border_width == 0)
      assert(cells[1].left_border_width == 0)

      assert(cells[2].parent == @row)
      assert(cells[2].width == 250)
      assert(cells[2].top_border_width == 5)
      assert(cells[2].right_border_width == 10)
      assert(cells[2].bottom_border_width == 15)
      assert(cells[2].left_border_width == 20)

      cells[0].top_border_width    = 25
      cells[0].bottom_border_width = 1
      cells[0].left_border_width   = 89
      cells[0].right_border_width  = 57

      assert(cells[0].top_border_width == 25)
      assert(cells[0].right_border_width == 57)
      assert(cells[0].bottom_border_width == 1)
      assert(cells[0].left_border_width == 89)

      cells[0].top_border_width    = 0
      cells[0].bottom_border_width = nil
      cells[0].left_border_width   = -5
      cells[0].right_border_width  = -1000

      assert(cells[0].top_border_width == 0)
      assert(cells[0].right_border_width == 0)
      assert(cells[0].bottom_border_width == 0)
      assert(cells[0].left_border_width == 0)

      assert(cells[2].border_widths == [5, 10, 15, 20])
   end

   def test_exceptions
      begin
         @row[0].paragraph
         flunk("Successfully called the TableCellNode#paragraph method.")
      rescue
      end

      begin
         @row[0].parent = nil
         flunk("Successfully called the TableCellNode#parent= method.")
      rescue
      end

      begin
         @row[0].table
         flunk("Successfully called the TableCellNode#table method.")
      rescue
      end
   end

   def test_rtf_generation
      cells = []
      cells.push(TableCellNode.new(@row))
      cells.push(TableCellNode.new(@row))
      cells[1] << "Added text."

      assert(cells[0].to_rtf == "\\pard\\intbl\n\n\\cell")
      assert(cells[1].to_rtf == "\\pard\\intbl\nAdded text.\n\\cell")
   end
end
