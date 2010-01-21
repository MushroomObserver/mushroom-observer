#!/usr/bin/env ruby

require 'test/unit'
require 'rtf'
require 'stringio'

include RTF

# Information class unit test class.
class InformationTest < Test::Unit::TestCase
   def test_01
      date = Time.local(1985, 6, 22, 14, 33, 22)
      info = []
      info.push(Information.new)
      info.push(Information.new('Title 1'))
      info.push(Information.new('Title 2', 'Peter Wood'))
      info.push(Information.new('La la la', '', 'Nowhere Ltd.'))
      info.push(Information.new('', 'N. O. Body', 'Oobly', 'Joobly'))
      info.push(Information.new('Title 5', 'J. Bloggs', '', '', date))
      info.push(Information.new('Title 6', 'J. Bloggs', '', '', '1985-06-22 14:33:22 GMT'))

      assert(info[0].title == nil)
      assert(info[0].author == nil)
      assert(info[0].company == nil)
      assert(info[0].comments == nil)

      assert(info[1].title == 'Title 1')
      assert(info[1].author == nil)
      assert(info[1].company == nil)
      assert(info[1].comments == nil)

      assert(info[2].title == 'Title 2')
      assert(info[2].author == 'Peter Wood')
      assert(info[2].company == nil)
      assert(info[2].comments == nil)

      assert(info[3].title == 'La la la')
      assert(info[3].author == '')
      assert(info[3].company == 'Nowhere Ltd.')
      assert(info[3].comments == nil)

      assert(info[4].title == '')
      assert(info[4].author == 'N. O. Body')
      assert(info[4].company == 'Oobly')
      assert(info[4].comments == 'Joobly')

      assert(info[5].title == 'Title 5')
      assert(info[5].author == 'J. Bloggs')
      assert(info[5].company == '')
      assert(info[5].comments == '')
      assert(info[5].created == date)

      assert(info[6].title == 'Title 6')
      assert(info[6].author == 'J. Bloggs')
      assert(info[6].company == '')
      assert(info[6].comments == '')
      assert(info[6].created == date)

      info[6].title = 'Alternative Title'
      assert(info[6].title == 'Alternative Title')

      info[6].author = 'A. Person'
      assert(info[6].author == 'A. Person')

      info[6].company = nil
      assert(info[6].company == nil)

      info[6].comments = 'New information comment text.'
      assert(info[6].comments == 'New information comment text.')

      date = Time.new
      info[6].created = date
      assert(info[6].created == date)

      date = Time.local(1985, 6, 22, 14, 33, 22)
      info[6].created = '1985-06-22 14:33:22 GMT'
      assert(info[6].created == date)

      assert(info[0].to_s(2) == "  Information\n     Created:  "\
                                "#{info[0].created}")
      assert(info[1].to_s(4) == "    Information\n       Title:    Title 1\n"\
                                "       Created:  #{info[1].created}")
      assert(info[2].to_s(-10) == "Information\n   Title:    Title 2\n   "\
                                  "Author:   Peter Wood\n   Created:  "\
                                  "#{info[2].created}")
      assert(info[3].to_s == "Information\n   Title:    La la la\n   "\
                             "Author:   \n   Company:  Nowhere Ltd.\n   "\
                             "Created:  #{info[3].created}")
      assert(info[4].to_s == "Information\n   Title:    \n   Author:   "\
                             "N. O. Body\n   Company:  Oobly\n   Comments: "\
                             "Joobly\n   Created:  #{info[4].created}")
      assert(info[5].to_s == "Information\n   Title:    Title 5\n   Author:   "\
                             "J. Bloggs\n   Company:  \n   Comments: \n   "\
                             "Created:  #{date}")
      assert(info[6].to_s == "Information\n   Title:    Alternative Title"\
                             "\n   Author:   A. Person\n   Comments: New "\
                             "information comment text.\n   Created:  #{date}")

      assert(info[0].to_rtf(3) == "   {\\info\n   #{to_rtf(info[0].created)}"\
                                  "\n   }")
      assert(info[1].to_rtf(6) == "      {\\info\n      {\\title Title 1}\n"\
                                  "      #{to_rtf(info[1].created)}\n      }")
      assert(info[2].to_rtf(-5) == "{\\info\n{\\title Title 2}\n"\
                                   "{\\author Peter Wood}\n"\
                                   "#{to_rtf(info[2].created)}\n}")
      assert(info[3].to_rtf == "{\\info\n{\\title La la la}\n"\
                               "{\\author }\n"\
                               "{\\company Nowhere Ltd.}\n"\
                               "#{to_rtf(info[3].created)}\n}")
      assert(info[4].to_rtf == "{\\info\n{\\title }\n"\
                               "{\\author N. O. Body}\n"\
                               "{\\company Oobly}\n"\
                               "{\\doccomm Joobly}\n"\
                               "#{to_rtf(info[4].created)}\n}")
      assert(info[5].to_rtf(3) == "   {\\info\n   {\\title Title 5}\n"\
                                  "   {\\author J. Bloggs}\n"\
                                  "   {\\company }\n"\
                                  "   {\\doccomm }\n"\
                                  "   #{to_rtf(date)}\n   }")
      assert(info[6].to_rtf == "{\\info\n{\\title Alternative Title}\n"\
                               "{\\author A. Person}\n"\
                               "{\\doccomm New information comment text.}\n"\
                               "#{to_rtf(date)}\n}")
   end

   def to_rtf(time)
      text = StringIO.new
      text << "{\\createim\\yr#{time.year}"
      text << "\\mo#{time.month}\\dy#{time.day}"
      text << "\\hr#{time.hour}\\min#{time.min}}"
      text.string
   end
end