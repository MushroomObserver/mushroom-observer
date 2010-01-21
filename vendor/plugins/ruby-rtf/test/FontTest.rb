#!/usr/bin/env ruby

require 'test/unit'
require 'rtf'

include RTF

# Font class unit test class.
class FontTest < Test::Unit::TestCase
   def test_01
      fonts = []
      fonts.push(Font.new(Font::MODERN, "Courier New"))
      fonts.push(Font.new(Font::ROMAN, "Arial"))
      fonts.push(Font.new(Font::SWISS, "Tahoma"))
      fonts.push(Font.new(Font::NIL, "La La La"))

      assert(fonts[0] == fonts[0])
      assert(!(fonts[0] == fonts[1]))
      assert(!(fonts[1] == 'a string of text'))
      assert(fonts[2] == Font.new(Font::SWISS, "Tahoma"))

      assert(fonts[0].family == Font::MODERN)
      assert(fonts[1].family == Font::ROMAN)
      assert(fonts[2].family == Font::SWISS)
      assert(fonts[3].family == Font::NIL)

      assert(fonts[0].name == 'Courier New')
      assert(fonts[1].name == 'Arial')
      assert(fonts[2].name == 'Tahoma')
      assert(fonts[3].name == 'La La La')

      assert(fonts[0].to_s == 'Family: modern, Name: Courier New')
      assert(fonts[1].to_s(3) == '   Family: roman, Name: Arial')
      assert(fonts[2].to_s(6) == '      Family: swiss, Name: Tahoma')
      assert(fonts[3].to_s(-1) == 'Family: nil, Name: La La La')

      assert(fonts[0].to_rtf == '\fmodern Courier New;')
      assert(fonts[1].to_rtf(2) == '  \froman Arial;')
      assert(fonts[2].to_rtf(4) == '    \fswiss Tahoma;')
      assert(fonts[3].to_rtf(-6) == '\fnil La La La;')

      begin
         Font.new(12345, "Ningy")
         flunk("Created a Font object with an invalid family setting.")
      rescue RTFError
      rescue Test::Unit::AssertionFailedError => error
         raise error
      rescue => error
         flunk("Unexpected exception caught checking font creation with "\
               "an invalid family. Exception type #{error.class.name}.")
      end
   end
end