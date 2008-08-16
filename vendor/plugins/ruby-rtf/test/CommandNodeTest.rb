#!/usr/bin/env ruby

require 'rubygems'
require 'test/unit'
require 'rtf'

include RTF

# Information class unit test class.
class CommandNodeTest < Test::Unit::TestCase
   def test_basics
      nodes = []
      nodes.push(CommandNode.new(nil, 'prefix'))
      nodes.push(CommandNode.new(nil, '', 'lalala'))
      nodes.push(CommandNode.new(nodes[0], '', nil, false))

      assert(nodes[0].prefix == 'prefix')
      assert(nodes[1].prefix == '')
      assert(nodes[2].prefix == '')

      assert(nodes[0].suffix == nil)
      assert(nodes[1].suffix == 'lalala')
      assert(nodes[2].suffix == nil)

      assert(nodes[0].split == true)
      assert(nodes[1].split == true)
      assert(nodes[2].split == false)
   end

   # Test line breaks.
   def test_line_break
      root = CommandNode.new(nil, nil)

      assert(root.line_break == nil)
      assert(root.size == 1)
      assert(root[0].class == CommandNode)
      assert(root[0].prefix == '\line')
      assert(root[0].suffix == nil)
      assert(root[0].split == false)
   end

   # Test paragraphs.
   def test_paragraph
      root  = CommandNode.new(nil, nil)
      style = ParagraphStyle.new

      assert(root.paragraph(style) != nil)
      assert(root.size == 1)
      assert(root[0].class == CommandNode)
      assert(root[0].prefix == '\pard\ql')
      assert(root[0].suffix == '\par')
      assert(root.split == true)

      style.justification = ParagraphStyle::RIGHT_JUSTIFY
      assert(root.paragraph(style).prefix == '\pard\qr')

      style.justification = ParagraphStyle::CENTRE_JUSTIFY
      assert(root.paragraph(style).prefix == '\pard\qc')

      style.justification = ParagraphStyle::FULL_JUSTIFY
      assert(root.paragraph(style).prefix == '\pard\qj')

      style.justification = ParagraphStyle::LEFT_JUSTIFY
      style.space_before = 100
      root.paragraph(style)
      assert(root[-1].prefix == '\pard\ql\sb100')

      style.space_before = nil
      style.space_after  = 1234
      root.paragraph(style)
      assert(root[-1].prefix == '\pard\ql\sa1234')

      style.space_before = nil
      style.space_after  = nil
      style.left_indent  = 10
      root.paragraph(style)
      assert(root[-1].prefix == '\pard\ql\li10')

      style.space_before = nil
      style.space_after  = nil
      style.left_indent  = nil
      style.right_indent = 234
      root.paragraph(style)
      assert(root[-1].prefix == '\pard\ql\ri234')

      style.space_before      = nil
      style.space_after       = nil
      style.left_indent       = nil
      style.right_indent      = nil
      style.first_line_indent = 765
      root.paragraph(style)
      assert(root[-1].prefix == '\pard\ql\fi765')

      style.space_before      = 12
      style.space_after       = 23
      style.left_indent       = 34
      style.right_indent      = 45
      style.first_line_indent = 56
      root.paragraph(style)
      assert(root[-1].prefix == '\pard\ql\li34\ri45\fi56\sb12\sa23')

      node = nil
      root.paragraph(style) {|n| node = n}
      assert(node == root[-1])
   end

   # Test applications of styles.
   def test_style
      root  = Document.new(Font.new(Font::ROMAN, 'Arial'))
      style = CharacterStyle.new
      style.bold = true

      assert(root.apply(style) != nil)
      assert(root.size == 1)
      assert(root[0].class == CommandNode)
      assert(root[0].prefix == '\b')
      assert(root[0].suffix == nil)
      assert(root[0].split == true)

      style.underline = true
      assert(root.apply(style).prefix == '\b\ul')

      style.bold        = false
      style.superscript = true
      assert(root.apply(style).prefix == '\ul\super')

      style.underline = false
      style.italic    = true
      assert(root.apply(style).prefix == '\i\super')

      style.italic = false
      style.bold   = true
      assert(root.apply(style).prefix == '\b\super')

      style.bold        = false
      style.superscript = false
      style.italic      = true
      style.font_size   = 20
      assert(root.apply(style).prefix == '\i\fs20')

      node = nil
      root.apply(style) {|n| node = n}
      assert(node == root[-1])

      # Test style short cuts.
      node = root.bold
      assert(node.prefix == '\b')
      assert(node.suffix == nil)
      assert(node == root[-1])

      node = root.italic
      assert(node.prefix == '\i')
      assert(node.suffix == nil)
      assert(node == root[-1])

      node = root.underline
      assert(node.prefix == '\ul')
      assert(node.suffix == nil)
      assert(node == root[-1])

      node = root.superscript
      assert(node.prefix == '\super')
      assert(node.suffix == nil)
      assert(node == root[-1])
   end

   # Test text node addition.
   def test_text
      root = CommandNode.new(nil, nil)

      root << 'A block of text.'
      assert(root.size == 1)
      assert(root[0].class == TextNode)
      assert(root[0].text == 'A block of text.')

      root << " More text."
      assert(root.size == 1)
      assert(root[0].class == TextNode)
      assert(root[0].text == 'A block of text. More text.')

      root.paragraph
      root << "A new node."
      assert(root.size == 3)
      assert(root[0].class == TextNode)
      assert(root[-1].class == TextNode)
      assert(root[0].text == 'A block of text. More text.')
      assert(root[-1].text == 'A new node.')
   end

   # Test table addition.
   def test_table
      root  = CommandNode.new(nil, nil)

      table = root.table(3, 3, 100, 150, 200)
      assert(root.size == 1)
      assert(root[0].class == TableNode)
      assert(root[0] == table)
      assert(table.rows == 3)
      assert(table.columns == 3)

      assert(table[0][0].width == 100)
      assert(table[0][1].width == 150)
      assert(table[0][2].width == 200)
   end

   # This test checks the previous_node and next_node methods that could not be
   # fully and properly checked in the NodeTest.rb file.
   def test_peers
      root  = Document.new(Font.new(Font::ROMAN, 'Arial'))
      nodes = []
      nodes.push(root.paragraph)
      nodes.push(root.bold)
      nodes.push(root.underline)

      assert(root.previous_node == nil)
      assert(root.next_node == nil)
      assert(nodes[1].previous_node == nodes[0])
      assert(nodes[1].next_node == nodes[2])
   end
end
