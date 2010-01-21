#!/usr/bin/env ruby

require 'rubygems'
require 'test/unit'
require 'rtf'

include RTF

# Information class unit test class.
class ContainerNodeTest < Test::Unit::TestCase
   def test01
      nodes = []
      nodes.push(ContainerNode.new(nil))
      nodes.push(ContainerNode.new(nodes[0]))
      
      assert(nodes[0].size == 0)
      assert(nodes[1].size == 0)
      
      assert(nodes[0].first == nil)
      assert(nodes[0].last == nil)
      assert(nodes[1].first == nil)
      assert(nodes[1].last == nil)
      
      assert(nodes[0][0] == nil)
      assert(nodes[1][-1] == nil)
      
      count = 0
      nodes[0].each {|entry| count += 1}
      assert(count == 0)
      nodes[1].each {|entry| count += 1}
      assert(count == 0)
   end
   
   def test02
      node   = ContainerNode.new(nil)
      child1 = ContainerNode.new(nil)
      child2 = ContainerNode.new(nil)
      
      node.store(child1)
      assert(node.size == 1)
      assert(node[0] == child1)
      assert(node[-1] == child1)
      assert(node[0].parent == node)
      assert(node.first == child1)
      assert(node.last == child1)
      
      count = 0
      node.each {|entry| count += 1}
      assert(count == 1)
      
      node.store(child2)
      assert(node.size == 2)
      assert(node[0] == child1)
      assert(node[1] == child2)
      assert(node[-1] == child2)
      assert(node[-2] == child1)
      assert(node[0].parent == node)
      assert(node[1].parent == node)
      assert(node.first == child1)
      assert(node.last == child2)
   end
   
   def test03
      begin
         ContainerNode.new(nil).to_rtf
         flunk("Successfully called ContainerNode#to_rtf().")
      rescue => error
      end
   end
end
