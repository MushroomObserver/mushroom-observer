#
#  == Textile Parser
#
#  This class -- a subclass of String -- is a wrapper on RedCloth.  It provides
#  some extra proprietary syntax on top of the standard Textile as implemented
#  by RedCloth, such as turning _Species name_ into a link to
#  <tt>lookup_name/Species%20name</tt>.
#
#  === Class methods
#
#  textilize::                   Parse the given string.
#  textilize_without_paragraph:: Parse the first paragraph of the given string.
#  ---
#  register_name::               Register a set of names that _S. name_ abbreviations may refer to.
#  textile_name_size::           Report on the current size of the name lookup cache.
#  clear_textile_cache::         Flush the name lookup cache.
#
#  === Instance methods
#
#  textilize::                   Parse the given string.
#  textilize_without_paragraph:: Parse the first paragraph of the given string.
#
################################################################################

class Textile < String
  if !defined?(URI_ESCAPE)
    URL_TRUNCATION_LENGTH = 60

    URI_ESCAPE = {
      ' '  => '%20',
      '"'  => '%22',
      '?'  => '%3F',
      '='  => '%3D',
      '&'  => '%26',
      '%'  => '%61',
      '<'  => '%3C',
      '>'  => '%3E',
      '\\' => '%5C',
    }
  end

  # Convenience wrapper on the instance method
  # Textile#textilize_without_paragraph.
  def self.textilize_without_paragraph(str, do_object_links=false)
    new(str).textilize_without_paragraph(do_object_links)
  end

  # Convenience wrapper on the instance method Textile#textilize.
  def self.textilize(str, do_object_links=false)
    new(str).textilize(do_object_links)
  end

  # Wrapper on textilize that returns only the body of the first paragraph of
  # the result.
  def textilize_without_paragraph(do_object_links=false)
    textilize(do_object_links).sub(/\A<p[^>]*>(.*?)<\/p>.*/m, '\\1')
  end

  # Textilizes the string using RedCloth, doing a little extra processing:
  # 1. it fixes long urls by turning them into links and abbreviating the
  #    text actually shown.
  # 2. converts _object_ constructs into appropriate links (unless told not to).
  #
  # There are a number of related methods and shorthand aliases:
  # textilize::                   The general case.
  # textilize_without_paragraph:: Just returns body of first paragraph.
  # ---
  # String#t::                    Same as textilize_without_paragraph(false).
  # String#tl::                   Same as textilize_without_paragraph(true).
  # String#tp::                   Same as textilize(false).
  # String#tpl::                  Same as textilize(true).
  #
  # Here are some mnemonics for the aliases:
  # t::    Just textilize: no paragraphs or links or anything fancy.
  # tl::   Do 't' and check for links.
  # tp::   Wrap 't' in a <p> block.
  # tpl::  Wrap 't' in a <p> block AND do links.
  def textilize(do_object_links=false)

    # This converts the "_object blah_" constructs into "x{OBJECT id label}x".
    # (The "x"s prevent Textile from interpreting the curlies as style info.)
    if do_object_links
      check_name_links!
      check_other_links!
      check_our_images!
    end

    # Let Textile munge the thing up now.
    replace(RedCloth.new(self).to_html)

    # Remove pre-existing links first, replacing with "<XXXnn>".
    hrefs = []
    gsub!(/(<a[^>]*>.*?<\/a>|<img[^>]*>)/) do |href|
      if do_object_links
        href = href.gsub(/
          x\{([A-Z]+) \s+ ([^\{\}]+?) \s+\}\{\s+ ([^\{\}]+?) \s+\}x
        /x, '\\2')
      end
      hrefs.push(href)
      "<XXX#{hrefs.length - 1}>"
    end

    # Now turn bare urls into links.
    gsub!(/([a-z]+:\/\/[^\s<>]+)/) do |url|
      extra = url.sub!(/([^\w\/]+$)/, '') ? $1 : ''
      url2 = ''
      if url.length > URL_TRUNCATION_LENGTH and not url.starts_with?(HTTP_DOMAIN)
        if url.match(/^(\w+:\/\/[^\/]+)(.*?)$/)
          url2 = $1 + '/...'
        else
          url2 = url[0..URL_TRUNCATION_LENGTH] + '...'
        end
      else
        url2 = url
      end
      url.gsub!(/([ "%<>\\])/) {URI_ESCAPE[$1]}
      "<a href=\"#{url}\">#{url2}</a>"
    end

    # Convert _object_ tags into proper links.
    if do_object_links
      gsub!(/
        x\{([A-Z]+) \s+ ([^\{\}]+?) \s+\}\{\s+ ([^\{\}]+?) \s+\}x
      /x) do |orig|
        type, label, id = $1, $2, $3
        id.gsub!(/([ "%?=&<>\\])/) {URI_ESCAPE[$1]}
        url = "#{HTTP_DOMAIN}/observer/lookup_#{type.downcase}/#{id}"
        "<a href=\"#{url}\">#{label}</a>"
      end
    end

    # Make sure all links are fully-qualified.
    gsub!(/href="\//, "href=\"#{HTTP_DOMAIN}/")

    # Put pre-existing links back in (removing the _object_ tag wrappers).
    gsub!(/<XXX(\d+)>/) do
      hrefs[$1.to_i].to_s.gsub(/ x\{ ([^\{\}]*) \}x /x, '\\1')
    end

    return self
  end

  # Register one or more names (instances) so that subsequent textile strings
  # can refer to them by abbreviation.
  def self.register_name(*names)
    for name in names
      if name && name.respond_to?('text_name') && !name.above_genus?
        @@name_lookup ||= {}
        name.text_name.match(/([A-Z])/)
        @@name_lookup[$1] = name.text_name.split.first
        @@last_species    = name.text_name if name.rank == :Species
        @@last_subspecies = name.text_name if name.rank == :Subspecies
        @@last_variety    = name.text_name if name.rank == :Variety
      end
    end
  end

  # Report the current size of the name lookup cache.
  def self.textile_name_size
    @@name_lookup ||= {}
    @@name_lookup.size
  end

  # Flush the name lookup cache.
  def self.clear_textile_cache
    @@name_lookup = {}
  end

##############################################################################

private

  # Convert __Names__ to links in a textile string.
  def check_name_links!
    @@name_lookup ||= {}

    # Look for __Name__ turn into "Name":name_id.  Look for "Name":name and
    # fill in id.  Look for "Name":name_id and make sure id matches name just
    # in case the user changed the name without updating the id.
    self.gsub!(/
      (^|\W)
        (?:\**_+)
        (
          "?[A-Z](?:[a-z\-]*|\.)"?
            (?: (?:\s+ (?:[a-z]+\.\s+)? "?[a-z\-]+"? )* | \s+ sp\. ) |
          (?:subsp|ssp|var|v|forma?|f)\.? \s+ "?[a-zë\-]+"?
        ) (
          \s+
          (?: "?[^a-z"\s_] | in\s?ed\.? | auct\.? | van\sd[a-z]+\s[A-Z] |
              s[\.\s] | sensu\s )
          [^_]*
        )?
        (?:_+\**)
      (?= (?:s|ish|like)? (?:\W|’|\Z) )
    /x) do |orig|
      result = orig
      prefix = $1.to_s
      name   = $2.to_s
      author = $3.to_s

      # Remove any formatting.
      str1 = (name + author).gsub(/[_*]/, '')

      # Expand abbreviated genus (but only if followed by species epithet!).
      str2 = str1.sub(/^([A-Z])\.? +(?=["a-z])/) do |x|
        (n = @@name_lookup[$1]) ? n + ' ' : x
      end

      # Expand bare variety, etc.  For example, after using Amanita muscaria:
      #   _var alba_  -->  Amanita muscaria var. alba
      # (This is not perfect: if subspecies and varieties are mixed it can mess up.)
      if str2.sub!(/^(subsp|ssp)\.? +/, '')
        str2 = @@last_species    ? @@last_species  + ' subsp. ' + str2 : ''
      elsif str2.sub!(/^(var|v)\.? +/, '')
        str2 = @@last_subspecies ? @@last_subspecies + ' var. ' + str2 :
               @@last_species    ? @@last_species    + ' var. ' + str2 : ''
      elsif str2.sub!(/^(forma?|f)\.? +/, '')
        str2 = @@last_variety    ? @@last_variety    + ' f. ' + str2 :
               @@last_subspecies ? @@last_subspecies + ' f. ' + str2 :
               @@last_species    ? @@last_species    + ' f. ' + str2 : ''
      end

      # Allow a number of author-like syntaxes that aren't normally allowed.
      # Remove them and match the rest.  Examples:
      #   _Laccaria cf. laccata_      -->  <a>**__Laccaria__**</a> __cf. laccata__
      #   _Peltigera aphthosa group_  -->  <a>**__Peltigera aphthosa__**</a> __group__
      #   _Parmelia s. lat._          -->  <a>**__Parmelia__**</a> __s. lat.__
      postfix = ''
      if str2.sub!(/ cf\.? (.*)/, '')
        postfix = ' cf. __%s__' % $1
      elsif str2.sub!(/ group$/, '')
        postfix = ' group'
      elsif str2.sub!(/ (s|sensu)\.? ?(l|lato|s|str|stricto)\.?$/, '')
        postfix = $2[0,1] == 's' ? ' s. str.' : ' s. lato'
      end

      # Allow "sensu Authors" that aren't in database.  Example:
      #   _S. riparia sensu A.H.Smith_  -->  <a>**__S. riparia__**</a> __sensu A.H.Smith__
      if !author.match(/sensu/) && str2.sub!(/ (sensu .*)/ ,'')
        postfix = ' ' + $1 + postfix
      end

      # Make sure the rest parses normally.
      if (parse = Name.parse_name(str2)) &&
        # Allowing arbitrary authors on Genera and higher makes it impossible to
        # distinguish between publication titles and taxa, e.g., "Lichen Flora
        # of the Greater Sonoran Region".  I'm sure it can still break with species
        # but it should be very infrequent (I don't see it in current tests). -JPH
        (author.blank? || parse[5] != :Genus)

        # Update which genus this first letter would mean in an abbrev.
        if parse[0].match(/([A-Z])/)
          @@name_lookup[$1] = parse[0] if parse[5] == :Genus
          @@last_species    = parse[0] if parse[5] == :Species
          @@last_subspecies = parse[0] if parse[5] == :Subspecies
          @@last_variety    = parse[0] if parse[5] == :Variety
        end

        # # Format name starting with bare text_name (no "sp." or author).
        # label = '__%s__' % parse[0]
        #
        # # Re-abbreviate genus if started that way.
        # label.sub!(/([A-Z])[a-zë\-]*/, '\\1.') if str1.match(/^[A-Z]\.? /)
        #
        # # De-itallicize "var.", "ssp.", etc.
        # label.gsub!(/ (var|subsp|f)\. /, '__ \\1. __')
        #
        # # Tack author on to end (if any).
        # label += ' ' + parse[6] if !parse[6].blank?

        # Hmmm... better not to reformat what the user entered at all.
        label = "__#{str1}__"

        # Put it all together.
        result = "#{prefix}x{NAME #{label} }{ #{str2} }x#{postfix}"
      end
      result
    end
  end

  # Convert _object name_ and _object id_ in a textile string.
  def check_other_links!
    self.gsub!(/
      (^|\W) (?:_+) ([a-z]+) \s+ ([^_\s](?:[^_\n]+[^_\s])?) (?:_+) (?!\w)
    /x) do |orig|
      result = orig
      prefix, type, id = $1, $2, $3
      if ['comment',
          'image',
          'location',
          'name',
          'observation',
          'project',
          'species_list',
          'user'
         ].include?(type.downcase)
        if id.match(/^\d+$/)
          label = "#{type.downcase.capitalize_first.to_sym.l} ##{id}"
        else
          label = id
        end
        result = "#{prefix}x{#{type.upcase} __#{label}__ }{ #{id} }x"
      end
      result
    end
  end

  # Convert !image 12345! in a textile string.
  def check_our_images!
    self.gsub!(/!image (\d+)!/) do
      '"!%s/thumb/%d.jpg!":%s/image/show_image/%d' %
        [IMAGE_DOMAIN, $1, HTTP_DOMAIN, $1]
    end
  end
end
