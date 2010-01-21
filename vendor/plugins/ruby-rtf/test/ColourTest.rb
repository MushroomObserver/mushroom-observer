#!/usr/bin/env ruby

require 'rubygems'
require 'test/unit'
require 'rtf'

include RTF

# Colour class unit test class.
class ColourTest < Test::Unit::TestCase
   def test_01
      colours = []
      colours.push(Colour.new(255, 255, 255))
      colours.push(Colour.new(200, 0, 0))
      colours.push(Colour.new(0, 150, 0))
      colours.push(Colour.new(0, 0, 100))
      colours.push(Colour.new(0, 0, 0))

      assert(colours[0] == colours[0])
      assert(!(colours[1] == colours[2]))
      assert(colours[3] == Colour.new(0, 0, 100))
      assert(!(colours[4] == 12345))

      assert(colours[0].red == 255)
      assert(colours[0].green == 255)
      assert(colours[0].blue == 255)

      assert(colours[1].red == 200)
      assert(colours[1].green == 0)
      assert(colours[1].blue == 0)

      assert(colours[2].red == 0)
      assert(colours[2].green == 150)
      assert(colours[2].blue == 0)

      assert(colours[3].red == 0)
      assert(colours[3].green == 0)
      assert(colours[3].blue == 100)

      assert(colours[4].red == 0)
      assert(colours[4].green == 0)
      assert(colours[4].blue == 0)

      assert(colours[0].to_s(3) == '   Colour (255/255/255)')
      assert(colours[1].to_s(6) == '      Colour (200/0/0)')
      assert(colours[2].to_s(-20) == 'Colour (0/150/0)')
      assert(colours[3].to_s == 'Colour (0/0/100)')
      assert(colours[4].to_s == 'Colour (0/0/0)')

      assert(colours[0].to_rtf(2) == '  \red255\green255\blue255;')
      assert(colours[1].to_rtf(4) == '    \red200\green0\blue0;')
      assert(colours[2].to_rtf(-6) == '\red0\green150\blue0;')
      assert(colours[3].to_rtf == '\red0\green0\blue100;')
      assert(colours[4].to_rtf == '\red0\green0\blue0;')

      begin
         Colour.new(256, 0, 0)
         flunk("Successfully created a colour with an invalid red setting.")
      rescue RTFError
      rescue Test::Unit::AssertionFailedError => error
         raise error
      rescue => error
         flunk("Unexpected exception caught. Type: #{error.class.name}\n"\
               "Message: #{error.message}")
      end

      begin
         Colour.new(0, 1000, 0)
         flunk("Successfully created a colour with an invalid green setting.")
      rescue RTFError
      rescue Test::Unit::AssertionFailedError => error
         raise error
      rescue => error
         flunk("Unexpected exception caught. Type: #{error.class.name}\n"\
               "Message: #{error.message}")
      end

      begin
         Colour.new(0, 0, -300)
         flunk("Successfully created a colour with an invalid blue setting.")
      rescue RTFError
      rescue Test::Unit::AssertionFailedError => error
         raise error
      rescue => error
         flunk("Unexpected exception caught. Type: #{error.class.name}\n"\
               "Message: #{error.message}")
      end

      begin
         Colour.new('La la la', 0, 0)
         flunk("Successfully created a colour with an invalid red type.")
      rescue RTFError
      rescue Test::Unit::AssertionFailedError => error
         raise error
      rescue => error
         flunk("Unexpected exception caught. Type: #{error.class.name}\n"\
               "Message: #{error.message}")
      end

      begin
         Colour.new(0, {}, 0)
         flunk("Successfully created a colour with an invalid green type.")
      rescue RTFError
      rescue Test::Unit::AssertionFailedError => error
         raise error
      rescue => error
         flunk("Unexpected exception caught. Type: #{error.class.name}\n"\
               "Message: #{error.message}")
      end

      begin
         Colour.new(0, 0, [])
         flunk("Successfully created a colour with an invalid blue type.")
      rescue RTFError
      rescue Test::Unit::AssertionFailedError => error
         raise error
      rescue => error
         flunk("Unexpected exception caught. Type: #{error.class.name}\n"\
               "Message: #{error.message}")
      end
   end
end
