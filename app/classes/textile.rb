# encoding: utf-8
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
  @@name_lookup     = {}
  @@last_species    = nil
  @@last_subspecies = nil
  @@last_variety    = nil

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
    gsub!(/([a-z]+:\/\/([^\s<>]|<span class="caps">[A-Z]+<\/span>)+)/) do |url|
      url1  = url.gsub(/<span class="caps">([A-Z]+)<\/span>/, '\\1')
      extra = url1.sub!(/([^\w\/]+$)/, '') ? $1 : ''
      url2  = ''
      if url1.length > URL_TRUNCATION_LENGTH and not url1.starts_with?(HTTP_DOMAIN)
        if url1.match(/^(\w+:\/\/[^\/]+)(.*?)$/)
          url2 = $1 + '/...'
        else
          url2 = url1[0..URL_TRUNCATION_LENGTH] + '...'
        end
      else
        url2 = url1
      end
      url1.gsub!(/([ "%<>\\])/) {URI_ESCAPE[$1]}
      "<a href=\"#{url1}\">#{url2}</a>" + extra
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
      if name and !name.above_genus?
        Textile.private_register_name(name.text_name, name.rank)
      end
    end
  end

  def self.private_register_name(name, rank)
    @@name_lookup ||= {}
    if name.match(/([A-Z])/)
      @@name_lookup[$1] = name.split.first
    end
    if rank == :Species
      @@last_species    = name
      @@last_subspecies = nil
      @@last_variety    = nil
    elsif rank == :Subspecies
      @@last_species    = name.sub(/ ssp\. .*/, '')
      @@last_subspecies = name
      @@last_variety    = nil
    elsif rank == :Variety
      @@last_species    = name.sub(/ (ssp|var)\. .*/, '')
      @@last_subspecies = name.sub(/ var\. .*/, '')
      @@last_variety    = name
    end
  end

  # Give unit test access to these internals.
  def self.name_lookup;     @@name_lookup;     end
  def self.last_species;    @@last_species;    end
  def self.last_subspecies; @@last_subspecies; end
  def self.last_variety;    @@last_variety;    end

  # Report the current size of the name lookup cache.
  def self.textile_name_size
    @@name_lookup ||= {}
    @@name_lookup.size
  end

  # Flush the name lookup cache.
  def self.clear_textile_cache
    @@name_lookup     = {}
    @@last_species    = nil
    @@last_subspecies = nil
    @@last_variety    = nil
  end

##############################################################################

# Privacy adds nothing of value to code, and just makes it a pain in the ass to test.
# private 

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
          "?[A-Z](?:\.|[a-z\-]*)"?
            (?: \s+ "?[a-zë\-]+"? (?:\s+ (?:subsp|ssp|var|v|forma?|f)\.? \s+ "?[a-zë\-]+"? )* |
                \s+ sp\. )? |
          (?:subsp|ssp|var|v|forma?|f)\.? \s+ "?[a-zë\-]+"?
        ) (
          \s+
          (?: "?[^a-z"\s_] | in\s?ed\.? | auct\.? | van\sd[a-z]+\s[A-Z] |
              s[\.\s] | sens[u\.]\s | group\s )
          [^_]*
        )?
        (?:_+\**)
      (?= (?:s|ish|like)? (?:\W|\Z) )
    /x) do |orig|
      prefix = $1.to_s
      name   = $2.to_s
      author = $3.to_s
      prefix + process_name_link(name, author)
    end
  end

  # Process the insides of a single __Name__ construct.
  def process_name_link(name, author)
    result = name + author

    # Remove any formatting. This will be the "label" of the link.
    str1 = (name + author).gsub(/[_*]/, '').gsub(/\s+/, ' ').strip

    # Expand abbreviated genus (but only if followed by species epithet!).
    # This will be sent to lookup_name.
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
    #   _Laccaria cf. laccata_     -->  Laccaria laccata
    #   _Parmelia s. lat/str._     -->  Parmelia
    str2.sub!(/ cfr?\.? /, ' ')
    str2.sub!(/ ((s|sensu)\.? ?(l|lato|s|str|stricto)\.?)$/, '')
    str2.sub!(/ sp\.$/, '')

    # Make sure the rest parses normally.
    if (parse = Name.parse_name(str2)) &&
      # Allowing arbitrary authors on Genera and higher makes it impossible to
      # distinguish between publication titles and taxa, e.g., "Lichen Flora
      # of the Greater Sonoran Region".  I'm sure it can still break with species
      # but it should be very infrequent (I don't see it in current tests). -JPH
      (author.blank? || parse[5] != :Genus)

      # Update which genus this first letter would mean in an abbrev.
      Textile.private_register_name(parse[0], parse[5])

      # Put it all together.
      result = "x{NAME __#{str1}__ }{ #{str2} }x"
    end

    result
  end

  # Convert _object name_ and _object id_ in a textile string.
  def check_other_links!
    self.gsub!(/
      (^|\W) (?:_+) ([a-zA-Z]+) \s+ ([^_\s](?:[^_\n]+[^_\s])?) (?:_+) (?!\w)
    /x) do |orig|
      result = orig
      prefix, type, id = $1, $2, $3
      matches = [
        ['comment'],
        ['image', 'img'],
        ['location', 'loc'],
        ['name'],
        ['observation', 'obs', 'ob'],
        ['project', 'proj'],
        ['species_list', 'spl'],
        ['user']
      ].select {|x| x[0] == type.downcase || x[1] == type.downcase}
      if matches.length == 1
        if id.match(/^\d+$/)
          label = "#{type} #{id}"
        else
          label = id
        end
        result = "#{prefix}x{#{matches.first.first.upcase} __#{label}__ }{ #{id} }x"
      end
      result
    end
  end

  # Convert !image 12345! in a textile string.
  def check_our_images!
    self.gsub!(/!image (\w+\/)?(\d+)!/) do
      size, id = $1, $2
      size ||= 'thumb/'
      '"!%s/%s%d.jpg!":%s/image/show_image/%d' %
        [IMAGE_DOMAIN, size, id, HTTP_DOMAIN, id]
    end
  end
end
