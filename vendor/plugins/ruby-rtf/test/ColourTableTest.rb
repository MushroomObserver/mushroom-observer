#!/usr/bin/env ruby

require 'test/unit'
require 'rtf'

include RTF

# ColourTable class unit test class.
class ColourTableTest < Test::Unit::TestCase
   def setup
      @colours = [Colour.new(0, 0, 0),
                  Colour.new(100, 100, 100),
                  Colour.new(150, 150, 150),
                  Colour.new(200, 200, 200),
                  Colour.new(250, 250, 250)]
   end

   def test_01
      tables = []
      tables.push(ColourTable.new)
      tables.push(ColourTable.new(@colours[0], @colours[2]))
      tables.push(ColourTable.new(*@colours))
      tables.push(ColourTable.new(@colours[0], @colours[1], @colours[0]))

      assert(tables[0].size == 0)
      assert(tables[1].size == 2)
      assert(tables[2].size == 5)
      assert(tables[3].size == 2)

      assert(tables[0][0] == nil)
      assert(tables[1][1] == @colours[2])
      assert(tables[2][3] == @colours[3])
      assert(tables[3][5] == nil)

      assert(tables[0].index(@colours[1]) == nil)
      assert(tables[1].index(@colours[2]) == 2)
      assert(tables[2].index(@colours[3]) == 4)
      assert(tables[3].index(@colours[4]) == nil)

      tables[0].add(@colours[0])
      assert(tables[0].size == 1)
      assert(tables[0].index(@colours[0]) == 1)

      tables[0] << @colours[1]
      assert(tables[0].size == 2)
      assert(tables[0].index(@colours[1]) == 2)

      tables[0].add(@colours[1])
      assert(tables[0].size == 2)
      assert([tables[0][0], tables[0][1]] == [@colours[0], @colours[1]])

      tables[0] << @colours[0]
      assert(tables[0].size == 2)
      assert([tables[0][0], tables[0][1]] == [@colours[0], @colours[1]])

      flags = [false, false, false, false, false]
      tables[2].each do |colour|
         flags[@colours.index(colour)] = true if @colours.index(colour) != nil
      end
      assert(flags.index(false) == nil)

      assert(tables[0].to_s(2) == "  Colour Table (2 colours)\n"\
                                  "     Colour (0/0/0)\n"\
                                  "     Colour (100/100/100)")
      assert(tables[1].to_s(4) == "    Colour Table (2 colours)\n"\
                                  "       Colour (0/0/0)\n"\
                                  "       Colour (150/150/150)")
      assert(tables[2].to_s(-6) == "Colour Table (5 colours)\n"\
                                   "   Colour (0/0/0)\n"\
                                   "   Colour (100/100/100)\n"\
                                   "   Colour (150/150/150)\n"\
                                   "   Colour (200/200/200)\n"\
                                   "   Colour (250/250/250)")
      assert(tables[3].to_s == "Colour Table (2 colours)\n"\
                               "   Colour (0/0/0)\n"\
                               "   Colour (100/100/100)")

      assert(tables[0].to_rtf(3) == "   {\\colortbl\n   ;\n"\
                                    "   \\red0\\green0\\blue0;\n"\
                                    "   \\red100\\green100\\blue100;\n"\
                                    "   }")
      assert(tables[1].to_rtf(6) == "      {\\colortbl\n      ;\n"\
                                    "      \\red0\\green0\\blue0;\n"\
                                    "      \\red150\\green150\\blue150;\n"\
                                    "      }")
      assert(tables[2].to_rtf(-9) == "{\\colortbl\n;\n"\
                                     "\\red0\\green0\\blue0;\n"\
                                     "\\red100\\green100\\blue100;\n"\
                                     "\\red150\\green150\\blue150;\n"\
                                     "\\red200\\green200\\blue200;\n"\
                                     "\\red250\\green250\\blue250;\n"\
                                     "}")
      assert(tables[3].to_rtf == "{\\colortbl\n;\n"\
                                 "\\red0\\green0\\blue0;\n"\
                                 "\\red100\\green100\\blue100;\n"\
                                 "}")
   end
end