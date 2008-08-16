#!/usr/bin/env ruby

require 'test/unit'
require 'rtf'

include RTF

# FontTable class unit test class.
class FontTableTest < Test::Unit::TestCase
   def setup
      @fonts = []
      @fonts.push(Font.new(Font::MODERN, "Courier New"))
      @fonts.push(Font.new(Font::ROMAN, "Arial"))
      @fonts.push(Font.new(Font::SWISS, "Tahoma"))
      @fonts.push(Font.new(Font::NIL, "La La La"))
   end

   def test_01
      tables = []
      tables.push(FontTable.new)
      tables.push(FontTable.new(@fonts[0], @fonts[2]))
      tables.push(FontTable.new(*@fonts))
      tables.push(FontTable.new(@fonts[0], @fonts[2], @fonts[0]))

      assert(tables[0].size == 0)
      assert(tables[1].size == 2)
      assert(tables[2].size == 4)
      assert(tables[3].size == 2)

      assert(tables[0][2] == nil)
      assert(tables[1][1] == @fonts[2])
      assert(tables[2][3] == @fonts[3])
      assert(tables[3][2] == nil)

      assert(tables[0].index(@fonts[0]) == nil)
      assert(tables[1].index(@fonts[2]) == 1)
      assert(tables[2].index(@fonts[2]) == 2)
      assert(tables[3].index(@fonts[1]) == nil)

      tables[0].add(@fonts[0])
      assert(tables[0].size == 1)
      assert(tables[0].index(@fonts[0]) == 0)

      tables[0] << @fonts[1]
      assert(tables[0].size == 2)
      assert(tables[0].index(@fonts[1]) == 1)

      tables[0].add(@fonts[0])
      assert(tables[0].size == 2)
      assert([tables[0][0], tables[0][1]] == [@fonts[0], @fonts[1]])

      tables[0] << @fonts[1]
      assert(tables[0].size == 2)
      assert([tables[0][0], tables[0][1]] == [@fonts[0], @fonts[1]])

      flags = [false, false, false, false]
      tables[2].each do |font|
         flags[@fonts.index(font)] = true if @fonts.index(font) != nil
      end
      assert(flags.index(false) == nil)

      assert(tables[0].to_s == "Font Table (2 fonts)\n"\
                               "   Family: modern, Name: Courier New\n"\
                               "   Family: roman, Name: Arial")
      assert(tables[1].to_s(6) == "      Font Table (2 fonts)\n"\
                                  "         Family: modern, Name: Courier New\n"\
                                  "         Family: swiss, Name: Tahoma")
      assert(tables[2].to_s(3) == "   Font Table (4 fonts)\n"\
                                  "      Family: modern, Name: Courier New\n"\
                                  "      Family: roman, Name: Arial\n"\
                                  "      Family: swiss, Name: Tahoma\n"\
                                  "      Family: nil, Name: La La La")
      assert(tables[3].to_s(-10) == "Font Table (2 fonts)\n"\
                                    "   Family: modern, Name: Courier New\n"\
                                    "   Family: swiss, Name: Tahoma")

      assert(tables[0].to_rtf == "{\\fonttbl\n"\
                                 "{\\f0\\fmodern Courier New;}\n"\
                                 "{\\f1\\froman Arial;}\n"\
                                 "}")
      assert(tables[1].to_rtf(4) == "    {\\fonttbl\n"\
                                    "    {\\f0\\fmodern Courier New;}\n"\
                                    "    {\\f1\\fswiss Tahoma;}\n"\
                                    "    }")
      assert(tables[2].to_rtf(2) == "  {\\fonttbl\n"\
                                    "  {\\f0\\fmodern Courier New;}\n"\
                                    "  {\\f1\\froman Arial;}\n"\
                                    "  {\\f2\\fswiss Tahoma;}\n"\
                                    "  {\\f3\\fnil La La La;}\n"\
                                    "  }")
      assert(tables[3].to_rtf(-6) == "{\\fonttbl\n"\
                                     "{\\f0\\fmodern Courier New;}\n"\
                                     "{\\f1\\fswiss Tahoma;}\n"\
                                     "}")
   end
end