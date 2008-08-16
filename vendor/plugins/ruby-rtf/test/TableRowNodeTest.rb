#!/usr/bin/env ruby

require 'rubygems'
require 'test/unit'
require 'rtf'

include RTF

# Information class unit test class.
class TableRowNodeTest < Test::Unit::TestCase
   def setup
      @table = TableNode.new(nil, 3, 3, 100, 100, 100)
   end

   def test_basics
      rows = []
      rows.push(TableRowNode.new(@table, 10))
      rows.push(TableRowNode.new(@table, 3, 100, 200, 300))

      assert(rows[0].size == 10)
      assert(rows[1].size == 3)

      assert(rows[0][0].width == TableCellNode::DEFAULT_WIDTH)
      assert(rows[0][1].width == TableCellNode::DEFAULT_WIDTH)
      assert(rows[0][2].width == TableCellNode::DEFAULT_WIDTH)
      assert(rows[0][3].width == TableCellNode::DEFAULT_WIDTH)
      assert(rows[0][4].width == TableCellNode::DEFAULT_WIDTH)
      assert(rows[0][5].width == TableCellNode::DEFAULT_WIDTH)
      assert(rows[0][6].width == TableCellNode::DEFAULT_WIDTH)
      assert(rows[0][7].width == TableCellNode::DEFAULT_WIDTH)
      assert(rows[0][8].width == TableCellNode::DEFAULT_WIDTH)
      assert(rows[0][9].width == TableCellNode::DEFAULT_WIDTH)
      assert(rows[1][0].width == 100)
      assert(rows[1][1].width == 200)
      assert(rows[1][2].width == 300)

      assert(rows[0][1].border_widths == [0, 0, 0, 0])
      rows[0].border_width = 10
      assert(rows[0][1].border_widths == [10, 10, 10, 10])
   end

   def test_exceptions
      row = TableRowNode.new(@table, 1)
      begin
         row.parent = nil
         flunk("Successfully called the TableRowNode#parent=() method.")
      rescue
      end
   end

   def test_rtf_generation
      rows = []
      rows.push(TableRowNode.new(@table, 3, 50, 50, 50))
      rows.push(TableRowNode.new(@table, 1, 134))
      rows[1].border_width = 5
      assert(rows[0].to_rtf == "\\trowd\\tgraph100\n\\cellx50\n\\cellx100\n"\
                               "\\cellx150\n\\pard\\intbl\n\n\\cell\n"\
                               "\\pard\\intbl\n\n\\cell\n"\
                               "\\pard\\intbl\n\n\\cell\n\\row")
      assert(rows[1].to_rtf == "\\trowd\\tgraph100\n"\
                               "\\clbrdrt\\brdrw5\\brdrs\\clbrdrl\\brdrw5\\brdrs"\
                               "\\clbrdrb\\brdrw5\\brdrs\\clbrdrr\\brdrw5\\brdrs"\
                               "\\cellx134\n\\pard\\intbl\n\n\\cell\n\\row")
   end
end
