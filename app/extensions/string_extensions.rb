#
#  = Extensions to String
#  == Class Methods
#  random::             Generate a random string.
#
#  == Instance Methods
#
#  t::                  Textilize (no paragraphs or obj links).
#  tl::                 Textilize with obj links (no paragraphs).
#  tp::                 Textilize with paragraphs (no obj links).
#  tpl::                Textilize with paragraphs and obj links.
#  tp_nodiv::           Textilize with paragraphs (no obj links, without div).
#  tpl_nodiv::          Textilize with paragraphs and obj links, without div).
#  ---
#  gsub!::              Gobal replace in place.
#  to_ascii::           Convert string from UTF-8 to plain ASCII.
#  iconv::              Convert string from UTF-8 to "charset".
#  strip_html::         Remove HTML tags (not entities) from string.
#  truncate_html::      Truncate an HTML string to N display characters.
#  html_to_ascii::      Convert HTML into plain text.
#  nowrap::             Surround HTML string inside '<nowrap>' span.
#  strip_squeeze::      Strip and squeeze spaces.
#  rand_char::          Pick a single random character from the string.
#  dealphabetize::      Reverse Integer#alphabetize.
#  is_ascii_character?:: Does string start with ASCII character?
#  is_nonascii_character?:: Does string start with non-ASCII character?
#  percent_match::      Measure how closely this String matches another String.
#  unindent::           Remove indentation (e.g., from here docs).
#  md5sum::             Calculate MD5 sum.
#
################################################################################

# MO extensions to Ruby String class
class String
  require "digest/md5"

  # :stopdoc:
  unless defined? UTF_TO_ASCII
    # This should cover most everything we'll see, at least all the European
    # characters and accents -- it covers HTML codes &#1 to &#400.
    UTF8_TO_ASCII = {
      "\x00"         => " ",
      "\x01"         => " ",
      "\x02"         => " ",
      "\x03"         => " ",
      "\x04"         => " ",
      "\x05"         => " ",
      "\x06"         => " ",
      "\x07"         => " ",
      "\x08"         => " ",
      "\x0B"         => " ",
      "\x0C"         => " ",
      "\x0E"         => " ",
      "\x0F"         => " ",
      "\x10"         => " ",
      "\x11"         => " ",
      "\x12"         => " ",
      "\x13"         => " ",
      "\x14"         => " ",
      "\x15"         => " ",
      "\x16"         => " ",
      "\x17"         => " ",
      "\x18"         => " ",
      "\x19"         => " ",
      "\x1A"         => " ",
      "\x1B"         => " ",
      "\x1C"         => " ",
      "\x1D"         => " ",
      "\x1E"         => " ",
      "\x1F"         => " ",
      "\xE2\x82\xAC" => "$",    # €
      "\xEF\xBF\xBD" => "?",    # �
      "\xE2\x80\x9A" => ",",    # ‚
      "\xC6\x92"     => "f",    # ƒ
      "\xE2\x80\x9E" => '"',    # „
      "\xE2\x80\xA6" => "...",  # …
      "\xE2\x80\xA0" => "+",    # †
      "\xE2\x80\xA1" => "++",   # ‡
      "\xCB\x86"     => "^",    # ˆ
      "\xE2\x80\xB0" => "%",    # ‰
      "\xE2\x80\xB9" => "<",    # ‹
      "\xE2\x80\x98" => "'",    # ‘
      "\xE2\x80\x99" => "'",    # ’
      "\xE2\x80\x9C" => '"',    # “
      "\xE2\x80\x9D" => '"',    # ”
      "\xE2\x80\xA2" => ".",    # •
      "\xE2\x80\x93" => "-",    # –
      "\xE2\x80\x94" => "-",    # —
      "\xCB\x9C"     => "~",    # ˜
      "\xE2\x84\xA2" => "(TM)", # ™
      "\xE2\x80\xBA" => ">",    # ›
      "\xC2\xA1"     => "!",    # ¡
      "\xC2\xA2"     => "$",    # ¢
      "\xC2\xA3"     => "$",    # £
      "\xC2\xA4"     => "$",    # ¤
      "\xC2\xA5"     => "$",    # ¥
      "\xC2\xA6"     => "|",    # ¦
      "\xC2\xA7"     => "?",    # §
      "\xC2\xA8"     => "?",    # ¨
      "\xC2\xA9"     => "(C)",  # ©
      "\xC2\xAA"     => "a",    # ª
      "\xC2\xAB"     => "<<",   # «
      "\xC2\xAC"     => "-",    # ¬
      "\xC2\xAD"     => "-",    # ­
      "\xC2\xAE"     => "(R)",  # ®
      "\xC2\xAF"     => "-",    # ¯
      "\xC2\xB0"     => "(o)",  # °
      "\xC2\xB1"     => "+/-",  # ±
      "\xC2\xB2"     => "(2)",  # ²
      "\xC2\xB3"     => "(3)",  # ³
      "\xC2\xB4"     => "'",    # ´
      "\xC2\xB5"     => "u",    # µ
      "\xC2\xB6"     => "?",    # ¶
      "\xC2\xB7"     => ".",    # ·
      "\xC2\xB8"     => ".",    # ¸
      "\xC2\xB9"     => "(1)",  # ¹
      "\xC2\xBA"     => "(0)",  # º
      "\xC2\xBB"     => ">>",   # »
      "\xC2\xBC"     => "1/4",  # ¼
      "\xC2\xBD"     => "1/2",  # ½
      "\xC2\xBE"     => "3/4",  # ¾
      "\xC2\xBF"     => "?",    # ¿
      "\xC3\x80"     => "A",    # À
      "\xC3\x81"     => "A",    # Á
      "\xC3\x82"     => "A",    # Â
      "\xC3\x83"     => "A",    # Ã
      "\xC3\x84"     => "A",    # Ä
      "\xC3\x85"     => "A",    # Å
      "\xC3\x86"     => "AE",   # Æ
      "\xC3\x87"     => "C",    # Ç
      "\xC3\x88"     => "E",    # È
      "\xC3\x89"     => "E",    # É
      "\xC3\x8A"     => "E",    # Ê
      "\xC3\x8B"     => "E",    # Ë
      "\xC3\x8C"     => "I",    # Ì
      "\xC3\x8D"     => "I",    # Í
      "\xC3\x8E"     => "I",    # Î
      "\xC3\x8F"     => "I",    # Ï
      "\xC3\x90"     => "D",    # Ð
      "\xC3\x91"     => "N",    # Ñ
      "\xC3\x92"     => "O",    # Ò
      "\xC3\x93"     => "O",    # Ó
      "\xC3\x94"     => "O",    # Ô
      "\xC3\x95"     => "O",    # Õ
      "\xC3\x96"     => "O",    # Ö
      "\xC3\x97"     => " x ",  # ×
      "\xC3\x98"     => "O",    # Ø
      "\xC3\x99"     => "U",    # Ù
      "\xC3\x9A"     => "U",    # Ú
      "\xC3\x9B"     => "U",    # Û
      "\xC3\x9C"     => "U",    # Ü
      "\xC3\x9D"     => "Y",    # Ý
      "\xC3\x9E"     => "P",    # Þ
      "\xC3\x9F"     => "ss",   # ß
      "\xC3\xA0"     => "a",    # à
      "\xC3\xA1"     => "a",    # á
      "\xC3\xA2"     => "a",    # â
      "\xC3\xA3"     => "a",    # ã
      "\xC3\xA4"     => "a",    # ä
      "\xC3\xA5"     => "a",    # å
      "\xC3\xA6"     => "ae",   # æ
      "\xC3\xA7"     => "c",    # ç
      "\xC3\xA8"     => "e",    # è
      "\xC3\xA9"     => "e",    # é
      "\xC3\xAA"     => "e",    # ê
      "\xC3\xAB"     => "e",    # ë
      "\xC3\xAC"     => "i",    # ì
      "\xC3\xAD"     => "i",    # í
      "\xC3\xAE"     => "i",    # î
      "\xC3\xAF"     => "i",    # ï
      "\xC3\xB0"     => "o",    # ð
      "\xC3\xB1"     => "n",    # ñ
      "\xC3\xB2"     => "o",    # ò
      "\xC3\xB3"     => "o",    # ó
      "\xC3\xB4"     => "o",    # ô
      "\xC3\xB5"     => "o",    # õ
      "\xC3\xB6"     => "o",    # ö
      "\xC3\xB7"     => "/",    # ÷
      "\xC3\xB8"     => "o",    # ø
      "\xC3\xB9"     => "u",    # ù
      "\xC3\xBA"     => "u",    # ú
      "\xC3\xBB"     => "u",    # û
      "\xC3\xBC"     => "u",    # ü
      "\xC3\xBD"     => "y",    # ý
      "\xC3\xBE"     => "p",    # þ
      "\xC3\xBF"     => "y",    # ÿ
      "\xC4\x3F"     => "c",    # č (where did this come from??)
      "\xC4\x80"     => "A",    # Ā
      "\xC4\x81"     => "a",    # ā
      "\xC4\x82"     => "A",    # Ă
      "\xC4\x83"     => "a",    # ă
      "\xC4\x84"     => "A",    # Ą
      "\xC4\x85"     => "a",    # ą
      "\xC4\x86"     => "C",    # Ć
      "\xC4\x87"     => "c",    # ć
      "\xC4\x88"     => "C",    # Ĉ
      "\xC4\x89"     => "c",    # ĉ
      "\xC4\x8A"     => "C",    # Ċ
      "\xC4\x8B"     => "c",    # ċ
      "\xC4\x8C"     => "C",    # Č
      "\xC4\x8D"     => "c",    # č
      "\xC4\x8E"     => "D",    # Ď
      "\xC4\x8F"     => "d",    # ď
      "\xC4\x90"     => "D",    # Đ
      "\xC4\x91"     => "d",    # đ
      "\xC4\x92"     => "E",    # Ē
      "\xC4\x93"     => "e",    # ē
      "\xC4\x94"     => "E",    # Ĕ
      "\xC4\x95"     => "e",    # ĕ
      "\xC4\x96"     => "E",    # Ė
      "\xC4\x97"     => "e",    # ė
      "\xC4\x98"     => "E",    # Ę
      "\xC4\x99"     => "e",    # ę
      "\xC4\x9A"     => "E",    # Ě
      "\xC4\x9B"     => "e",    # ě
      "\xC4\x9C"     => "G",    # Ĝ
      "\xC4\x9D"     => "g",    # ĝ
      "\xC4\x9E"     => "G",    # Ğ
      "\xC4\x9F"     => "g",    # ğ
      "\xC4\xA0"     => "G",    # Ġ
      "\xC4\xA1"     => "g",    # ġ
      "\xC4\xA2"     => "G",    # Ģ
      "\xC4\xA3"     => "g",    # ģ
      "\xC4\xA4"     => "H",    # Ĥ
      "\xC4\xA5"     => "h",    # ĥ
      "\xC4\xA6"     => "H",    # Ħ
      "\xC4\xA7"     => "h",    # ħ
      "\xC4\xA8"     => "I",    # Ĩ
      "\xC4\xA9"     => "i",    # ĩ
      "\xC4\xAA"     => "I",    # Ī
      "\xC4\xAB"     => "i",    # ī
      "\xC4\xAC"     => "I",    # Ĭ
      "\xC4\xAD"     => "i",    # ĭ
      "\xC4\xAE"     => "I",    # Į
      "\xC4\xAF"     => "i",    # į
      "\xC4\xB0"     => "I",    # İ
      "\xC4\xB1"     => "i",    # ı
      "\xC4\xB2"     => "IJ",   # Ĳ
      "\xC4\xB3"     => "ij",   # ĳ
      "\xC4\xB4"     => "J",    # Ĵ
      "\xC4\xB5"     => "j",    # ĵ
      "\xC4\xB6"     => "K",    # Ķ
      "\xC4\xB7"     => "k",    # ķ
      "\xC4\xB8"     => "k",    # ĸ
      "\xC4\xB9"     => "L",    # Ĺ
      "\xC4\xBA"     => "l",    # ĺ
      "\xC4\xBB"     => "L",    # Ļ
      "\xC4\xBC"     => "l",    # ļ
      "\xC4\xBD"     => "L",    # Ľ
      "\xC4\xBE"     => "l",    # ľ
      "\xC4\xBF"     => "L",    # Ŀ
      "\xC5\x80"     => "l",    # ŀ
      "\xC5\x81"     => "L",    # Ł
      "\xC5\x82"     => "l",    # ł
      "\xC5\x83"     => "N",    # Ń
      "\xC5\x84"     => "n",    # ń
      "\xC5\x85"     => "N",    # Ņ
      "\xC5\x86"     => "n",    # ņ
      "\xC5\x87"     => "N",    # Ň
      "\xC5\x88"     => "n",    # ň
      "\xC5\x89"     => "n",    # ŉ
      "\xC5\x8A"     => "N",    # Ŋ
      "\xC5\x8B"     => "n",    # ŋ
      "\xC5\x8C"     => "O",    # Ō
      "\xC5\x8D"     => "o",    # ō
      "\xC5\x8E"     => "O",    # Ŏ
      "\xC5\x8F"     => "o",    # ŏ
      "\xC5\x90"     => "O",    # Ő
      "\xC5\x91"     => "o",    # ő
      "\xC5\x92"     => "OE",   # Œ
      "\xC5\x93"     => "oe",   # œ
      "\xC5\x94"     => "R",    # Ŕ
      "\xC5\x95"     => "r",    # ŕ
      "\xC5\x96"     => "R",    # Ŗ
      "\xC5\x97"     => "r",    # ŗ
      "\xC5\x98"     => "R",    # Ř
      "\xC5\x99"     => "r",    # ř
      "\xC5\x9A"     => "S",    # Ś
      "\xC5\x9B"     => "s",    # ś
      "\xC5\x9C"     => "S",    # Ŝ
      "\xC5\x9D"     => "s",    # ŝ
      "\xC5\x9E"     => "S",    # Ş
      "\xC5\x9F"     => "s",    # ş
      "\xC5\xA0"     => "S",    # Š
      "\xC5\xA1"     => "s",    # š
      "\xC5\xA2"     => "T",    # Ţ
      "\xC5\xA3"     => "t",    # ţ
      "\xC5\xA4"     => "T",    # Ť
      "\xC5\xA5"     => "t",    # ť
      "\xC5\xA6"     => "T",    # Ŧ
      "\xC5\xA7"     => "t",    # ŧ
      "\xC5\xA8"     => "U",    # Ũ
      "\xC5\xA9"     => "u",    # ũ
      "\xC5\xAA"     => "U",    # Ū
      "\xC5\xAB"     => "u",    # ū
      "\xC5\xAC"     => "U",    # Ŭ
      "\xC5\xAD"     => "u",    # ŭ
      "\xC5\xAE"     => "U",    # Ů
      "\xC5\xAF"     => "u",    # ů
      "\xC5\xB0"     => "U",    # Ű
      "\xC5\xB1"     => "u",    # ű
      "\xC5\xB2"     => "U",    # Ų
      "\xC5\xB3"     => "u",    # ų
      "\xC5\xB4"     => "W",    # Ŵ
      "\xC5\xB5"     => "w",    # ŵ
      "\xC5\xB6"     => "Y",    # Ŷ
      "\xC5\xB7"     => "y",    # ŷ
      "\xC5\xB8"     => "Y",    # Ÿ
      "\xC5\xB9"     => "Z",    # Ź
      "\xC5\xBA"     => "z",    # ź
      "\xC5\xBB"     => "Z",    # Ż
      "\xC5\xBC"     => "z",    # ż
      "\xC5\xBD"     => "Z",    # Ž
      "\xC5\xBE"     => "z",    # ž
      "\xC5\xBF"     => "f",    # ſ
      "\xC6\x80"     => "b",    # ƀ
      "\xC6\x81"     => "B",    # Ɓ
      "\xC6\x82"     => "B",    # Ƃ
      "\xC6\x83"     => "b",    # ƃ
      "\xC6\x84"     => "b",    # Ƅ
      "\xC6\x85"     => "b",    # ƅ
      "\xC6\x86"     => "C",    # Ɔ
      "\xC6\x87"     => "C",    # Ƈ
      "\xC6\x88"     => "c",    # ƈ
      "\xC6\x89"     => "D",    # Ɖ
      "\xC6\x8A"     => "D",    # Ɗ
      "\xC6\x8B"     => "D",    # Ƌ
      "\xC6\x8C"     => "d",    # ƌ
      "\xC6\x8D"     => "g",    # ƍ
      "\xC6\x8E"     => "E",    # Ǝ
      "\xC6\x8F"     => "e",    # Ə
      "\xC6\x90"     => "E"     # Ɛ
    }.freeze
  end

  # Plain-text alternatives to the HTML special characters RedCloth uses.
  unless defined? HTML_SPECIAL_CHAR_EQUIVALENTS
    HTML_SPECIAL_CHAR_EQUIVALENTS = {
      "#64"   => "@",
      "amp"   => "&",
      "#38"   => "&",
      "gt"    => ">",
      "#62"   => ">",
      "lt"    => "<",
      "#60"   => "<",
      "quot"  => '"',
      "#34"   => '"',
      "#39"   => "'",
      "#169"  => "(c)",
      "#174"  => "(r)",
      "#215"  => "x",
      "#8211" => "-",
      "#8212" => "--",
      "#8216" => "'",
      "#8217" => "'",
      "#8220" => '"',
      "#8221" => '"',
      "#8230" => "...",
      "#8242" => "'",
      "#8243" => '"',
      "#8482" => "(tm)",
      "#8594" => "->",
      "nbsp"  => " "
    }.freeze
  end
  # :startdoc:

  # This should safely match anything that could possibly be interpreted as
  # an HTML tag.
  HTML_TAG_PATTERN = /<\/*[A-Za-z][^>]*>/

  ### Textile-related methods ###
  #
  def t(sanitize = true)
    Textile.textilize_without_paragraph(self, false, sanitize).html_safe
  end

  def tl(sanitize = true)
    Textile.textilize_without_paragraph(self, true, sanitize).html_safe
  end

  # TODO: Move somewhere that content_tag is defined
  def tp(sanitize = true)
    '<div class="textile">'.html_safe + Textile.textilize(self, false, sanitize).html_safe + "</div>".html_safe
  end

  def tpl(sanitize = true)
    '<div class="textile">'.html_safe +
      Textile.textilize(self, true, sanitize).html_safe +
      "</div>".html_safe
  end

  def tp_nodiv(sanitize = true)
    Textile.textilize(self, false, sanitize)
  end

  def tpl_nodiv(sanitize = true)
    Textile.textilize(self, true, sanitize)
  end

  ### String transformations ###
  #
  # Convert string (assumed to be in UTF-8) to plain ASCII.
  def to_ascii
    to_s.gsub(/[^\t\n\r\x20-\x7E]/) { |c| UTF8_TO_ASCII[c] || " " }
  end

  # Convert string (assumed to be in UTF-8) to any other charset.  All invalid
  # characters are degraded to their rough ASCII equivalent, then converted.
  def iconv(charset)
    encode(charset, fallback: lambda { |c| UTF8_TO_ASCII[c] || "?" })
  end

  # Escape a string to be safe to place in double-quotes inside javascript.
  # TODO: Use the rails method "j" for this
  def escape_js_string
    gsub(/(["\\])/, '\\\1').
      gsub(/\n/, '\\n')
  end

  # Remove HTML tags (not entities) from string.  Used to make sure title is
  # safe for HTML header field.
  def strip_html
    gsub(HTML_TAG_PATTERN, "")
  end

  # Remove hyperlinks from an HTML string.
  def strip_links
    gsub(/<\/?a.*?>/, "")
  end

  # Truncate an HTML string, being careful to close off any open formatting
  # tags.  If greater than +max+, truncates to <tt>max - 1</tt> and adds "..."
  # to the end (inside any formatting tags open at that point).  Assumes the
  # String is well-formatted HTML with properly-nested tags.
  def truncate_html(max)
    result = ""
    str = "" + self
    opens = []
    while str != ""
      # Self-closing tag.
      if str.sub!(/^<(\w+)[^<>]*\/ *>/, "")
        result += $&
      # Opening tag.
      elsif str.sub!(/^<(\w+)[^<>]*>/, "")
        result += $&
        opens << Regexp.last_match(1)
      # Closing tag -- just assume tags are nested properly.
      elsif str.sub!(/^< *\/ *(\w+)[^<>]*>/, "")
        result += $&
        opens.pop
      # Normal text.
      elsif str.sub!(/^[^<>]+/, "")
        part = $&
        if part.length > max
          result += part[0, max - 1].to_s + "..."
          break
        elsif part
          max -= part.length
          result += part
        end
      # All bets are off if not well-formatted HTML.
      else
        break
      end
    end
    result += opens.reverse.map { |x| "<\/#{x}>" }.join("")
    result.html_safe
  end

  # Attempt to turn HTML into plain text.  Remove all '<blah>' tags, and
  # convert '&blah;' codes into ASCII equivalents.  Line breaks may still be a
  # problem, but this seems to work pretty well on the output of RedCloth at
  # least.
  def html_to_ascii
    gsub(/\s*\n\s*/, " "). # remove all newlines first
      gsub(/<\/?div[^>]*>/, "").     # divs are messing things up, too
      gsub(/<br *\/> */, "\n").      # put \n after every line break
      gsub(/<\/li> */, "\n").        # put \n after every list item
      gsub(/<\/tr> */, "\n").        # put \n after every table row
      gsub(/<\/(p|h\d)> */, "\n\n"). # put two \n between paragraphs
      gsub(/<\/td> */, "\t").        # put tabs between table columns
      gsub(/[ \t]+(\n|$)/, '\\1').   # remove superfluous trailing whitespace
      gsub(/\n+\Z/, "").             # remove superfluous newlines at end
      gsub(HTML_TAG_PATTERN, "").    # remove all <tags>
      gsub(/^ +|[ \t]+$/, "").       # remove leading/trailing space on each line
      gsub(/&(#\d+|[a-zA-Z]+);/) { HTML_SPECIAL_CHAR_EQUIVALENTS[Regexp.last_match(1)].to_s }.
      html_safe                      # convert &xxx; and &#nnn; to ascii
  end

  # Surround HTML string with a span that prevents long strings from being
  # broken.
  def nowrap
    '<span style="white-space:nowrap">'.html_safe + self + "</span>".html_safe
  end

  # Strip leading and trailing spaces, and squeeze embedded spaces.
  # Differs from Rails "squish" which works on all whitespace
  #
  # The following two are equivalent:
  #
  #   string.strip_squeeze
  #   string.strip.squeeze(' ')
  #
  # Why?  Because it lets us do this:
  #
  #   names = text.split(/\n/).map(&:strip_squeeze)
  #
  def strip_squeeze
    strip.squeeze(" ")
  end

  # Uncamelizes and converts string to pluralized title. E.g.:
  # "Observation"  => "Observations"
  # "SpeciesList"  => "Species Lists"
  # "GlossaryTerm" => "Glossary Terms"
  # "good dog"     => "Good Dogs"
  def pluralized_title
    pluralize.underscore.humanize.titleize
  end

  # Generate a string of random characters of length +len+.  By default it
  # chooses from among the lowercase letters and digits, however you can give
  # it an arbitrary set of characters to choose from.  (And they don't have to
  # be unique, if you want to change the distribution a little bit.)
  #
  #   new_password = String.random(10)
  #
  def self.random(len, chars = "abcdefghijklmnopqrstuvwxyz0123456789")
    result = ""
    len.times { result += chars.to_s.rand_char }
    result
  end

  # Pick a random character from the String.  Result is a String of length 1.
  #
  #   char = "jabberwocky".rand_char
  #
  def rand_char
    self[Kernel.rand(length), 1]
  end

  # Reverse Integer#alphabetize.
  #
  #   string = integer.alphabetize
  #   integer = string.dealphabetize
  #   #   0         -> 0
  #   #   42        -> g
  #   #   123456789 -> 8M0kX
  #
  #   hex = decimal.alphabetize("0123456789ABCDEF")
  #   decimal = hex.dealphabetize("0123456789ABCDEF")
  #   #   0         -> 0
  #   #   42        -> 2A
  #   #   123456789 -> 75BCD15
  #
  def dealphabetize(alphabet = "0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz")
    str      = to_s
    alphabet = alphabet.to_s
    len      = alphabet.length
    str.split("").inject(0) do |num, char|
      i = alphabet.index(char)
      raise "Character not in alphabet: '#{char}'" if i.nil?

      num = num * len + i
    end
  end

  # Find amount first line is indented and remove that from all lines.
  def unindent
    gsub /^#{self[/\A\s*/]}/, ""
  end

  ### String Queries ###
  #
  # Does this string start with a ASCII character?
  def is_ascii_character?
    dup.force_encoding("binary")[0].ord < 128
  end

  # Returns percentage match between +self+ and +other+, where 1.0 means the two
  # strings are equal, and 0.0 means every character is different.
  def percent_match(other)
    max = [length, other.length].max
    1.0 - levenshtein_distance_to(other).to_f / max
  end

  # Returns number of character edits required to transform +self+ into +other+.
  def levenshtein_distance_to(other)
    levenshtein_distance(self, other)
  end

  # This definition copied from Rails::Generators, Which is based directly on
  # the Text gem implementation.
  def levenshtein_distance(str1, str2)
    s = str1
    t = str2
    n = s.length
    m = t.length

    return m if n.zero?
    return n if m.zero?

    d = (0..m).to_a
    x = nil

    str1.each_char.each_with_index do |char1, i|
      e = i + 1

      str2.each_char.each_with_index do |char2, j|
        cost = (char1 == char2 ? 0 : 1)
        x = [
          d[j + 1] + 1, # insertion
          e + 1,        # deletion
          d[j] + cost   # substitution
        ].min
        d[j] = e
        e = x
      end

      d[m] = x
    end

    x
  end

  # Returns the MD5 sum.
  def md5sum
    Digest::MD5.hexdigest(self)
  end

  ### Misc Utilities ###
  #
  def print_thing(thing)
    print "#{self}: #{thing.class}: #{thing}\n"
  end
end
