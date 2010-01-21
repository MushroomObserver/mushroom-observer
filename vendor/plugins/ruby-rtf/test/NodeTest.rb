#!/usr/bin/env ruby

require 'rubygems'
require 'test/unit'
require 'rtf'

include RTF

# Information class unit test class.
class NodeTest < Test::Unit::TestCase
   def test01
      nodes = []
      nodes.push(Node.new(nil))
      nodes.push(Node.new(nodes[0]))
      
      assert(nodes[0].parent == nil)
      assert(nodes[1].parent != nil)
      assert(nodes[1].parent == nodes[0])
      
      assert(nodes[0].is_root?)
      assert(nodes[1].is_root? == false)
      
      assert(nodes[0].root == nodes[0])
      assert(nodes[1].root == nodes[0])
      
      assert(nodes[0].previous_node == nil)
      assert(nodes[0].next_node == nil)
      assert(nodes[1].previous_node == nil)
      assert(nodes[1].next_node == nil)
   end
end
