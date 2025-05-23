# frozen_string_literal: true

require("redcloth")

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
#  textile_div_safe::  Wrap string in textile div, marking it safe for output
#  textilize_safe::              Same as above, marking it safe for output
#  textilize_without_paragraph:: Parse the first paragraph of the given string.
#  textilize_without_paragraph_safe  Same as above, marking it safe for output
#  ---
#  register_name::               Register a set of names that _S. name_
#                                abbreviations may refer to.
#  textile_name_size::           Report on current size of name lookup cache.
#  clear_textile_cache::         Flush the name lookup cache.
#
#  === Instance methods
#
#  textilize::                   Parse the given string.
#  textilize_without_paragraph:: Parse the first paragraph of the given string.
#
class Textile < String
  @@name_lookup     = {}
  @@last_species    = nil
  @@last_subspecies = nil
  @@last_variety    = nil

  URL_TRUNCATION_LENGTH = 60 unless defined?(URI_TRUNCATION_LENGTH)
  BRACKETED_YEAR = /\[(\d\d\d\d)\]/

  ########## Class methods #####################################################

  # Convenience wrapper on instance method Textile#textilize_without_paragraph.
  def self.textilize_without_paragraph(str, do_object_links: false,
                                       sanitize: true)
    new(str).textilize_without_paragraph(do_object_links: do_object_links,
                                         sanitize: sanitize)
  end

  # Wrap self.textilize_without_paragraph, marking output trusted safe
  def self.textilize_without_paragraph_safe(str, do_object_links: false,
                                            sanitize: true)
    textilize_without_paragraph(str, do_object_links: do_object_links,
                                     sanitize: sanitize).
      # Disable cop; we need `html_safe` to prevent Rails from adding escaping
      html_safe # rubocop:disable Rails/OutputSafety
  end

  # Convenience wrapper on the instance method Textile#textilize.
  def self.textilize(str, do_object_links: false, sanitize: true)
    new(str).textilize(do_object_links: do_object_links, sanitize: sanitize)
  end

  # Wrap self.textilize_without_paragraph, marking output trusted safe
  def self.textilize_safe(str, do_object_links: false, sanitize: true)
    textilize(str, do_object_links: do_object_links, sanitize: sanitize).
      # Disable cop; we need `html_safe` to prevent Rails from adding escaping
      html_safe # rubocop:disable Rails/OutputSafety
  end

  # Wrap string in textile div, marking output trusted safe
  def self.textile_div_safe
    %(<div class="textile">#{yield}</div>).
      # Disable cop; we need `html_safe` to prevent Rails from adding escaping
      html_safe # rubocop:disable Rails/OutputSafety
  end

  ########## Instance methods ##################################################

  # Wrapper on textilize that returns only the body of the first paragraph of
  # the result.
  def textilize_without_paragraph(do_object_links: false, sanitize: true)
    textilize(do_object_links: do_object_links, sanitize: sanitize).
      sub(%r{\A<p[^>]*>(.*?)</p>.*}m, '\\1')
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
  # String#t::   Same as textilize_without_paragraph(do_object_links: false)
  # String#tl::  Same as textilize_without_paragraph(do_object_links: true)
  # String#tp::  Same as textilize(do_object_links: false).
  # String#tpl:: Same as textilize(do_object_links: true).
  #
  # Here are some mnemonics for the aliases:
  # t::    Just textilize: no paragraphs or links or anything fancy.
  # tl::   Do 't' and check for links.
  # tp::   Wrap 't' in a <p> block.
  # tpl::  Wrap 't' in a <p> block AND do links.
  def textilize(do_object_links: false, sanitize: true)
    preprocess_object_links if do_object_links

    # Textile will screw with "@John Doe@".  We need to protect at signs now.
    gsub!("@", "&#64;")

    # Quote bracketed years
    # in order to stop RedCloth from turning them into footnote calls
    # Some Name Citations contain bracketed years. Ex:
    #   Hyménomycètes (Alençon): 103 (1874) [1878]
    # We want them to render as such, not footnote references.
    gsub!(BRACKETED_YEAR, '==[==\1]') if match?(BRACKETED_YEAR)

    # Let Textile munge the thing up now.
    red = RedCloth.new(self)

    red.sanitize_html = sanitize
    replace(red.to_html)

    # Strip <span class="caps">...</span> tags (leaving inner text intact).
    # When RedCloth.to_html sees an ALLCAPS word, it wraps it with these tags.
    # They mess up our url's. And we never need them. (We don't style "caps").
    strip_caps_class_spans!

    # Replace pre-existing links with "<XXXnn>" so that they aren't modified
    # by the following lines, saving the links so we can restore them later.
    saved_links = pre_existing_links_replaced_by_placeholders!(do_object_links)
    convert_bare_urls_to_links!
    convert_tagged_objects_to_proper_links!
    fully_qualify_links!
    restore_pre_existing_links!(saved_links)

    self
  end

  # Register one or more names (instances) so that subsequent textile strings
  # can refer to them by abbreviation.
  def self.register_name(*names)
    names.each do |name|
      next unless name.try(:at_or_below_genus?)

      Textile.private_register_name(name.user_real_text_name(nil), name.rank)
    end
  end

  def self.user_register_name(user, *names)
    names.each do |name|
      next unless name.try(:at_or_below_genus?)

      Textile.private_register_name(name.user_real_text_name(user), name.rank)
    end
  end

  def self.private_register_name(name, rank)
    @@name_lookup ||= {}
    @@name_lookup[Regexp.last_match(1)] = name.split.first if name =~ /([A-Z])/
    case rank
    when "Species"
      @@last_species    = name
      @@last_subspecies = nil
      @@last_variety    = nil
    when "Subspecies"
      @@last_species    = name.sub(/ ssp\. .*/, "")
      @@last_subspecies = name
      @@last_variety    = nil
    when "Variety"
      @@last_species    = name.sub(/ (ssp|var)\. .*/, "")
      @@last_subspecies = name.sub(/ var\. .*/, "")
      @@last_variety    = name
    end
  end

  # Give unit test access to these internals.
  def self.name_lookup
    @@name_lookup
  end

  def self.last_species
    @@last_species
  end

  def self.last_subspecies
    @@last_subspecies
  end

  def self.last_variety
    @@last_variety
  end

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

  private

  # This converts the "_object blah_" constructs into "x{OBJECT id label}x".
  # (The "x"s prevent Textile from interpreting the curlies as style info.)
  def preprocess_object_links
    convert_name_links_to_tagged_objects!
    convert_other_links_to_tagged_objects!
    convert_embedded_image_links_to_textile!
    convert_implicit_terms_to_tagged_glossary_terms!
  end

  MARKUP_TO_TAG = {
    comment: "COMMENT",
    glossary_term: "GLOSSARY_TERM",
    image: "IMAGE",
    img: "IMAGE",
    location: "LOCATION",
    loc: "LOCATION",
    name: "NAME",
    term: "GLOSSARY_TERM",
    ob: "OBSERVATION",
    obs: "OBSERVATION",
    observation: "OBSERVATION",
    project: "PROJECT",
    species_list: "SPECIES_LIST",
    spl: "SPECIES_LIST",
    user: "USER"
  }.freeze
  # case-insenstive match any of the non-Name markup tags
  NON_NAME_LINK_PATTERN =
    /#{(MARKUP_TO_TAG.keys - [:name]).map(&:to_s).join("|")}/i
  NAME_LINK_PATTERN = %r{
    (?<prefix> ^|\W) # capture start of string or non-word character
    (?: \**_+) # any asterisks then at least one underscore
    (?! #{NON_NAME_LINK_PATTERN}\ ) # not a link to a non-Name object
    (?<formatted_label> [^_]+) # capture all non-underscores
    (?: _+\**) # at least one underscore then any asterisks
    (?= # not followed by
      (?: s|ish|like)? # optional ns, ish, or like, then
      (?: \W|\Z) # non-word char or end of string
    )

    (?! (?: </[a-z]+>)) # discard match if followed by html closing tag
  }x
  private_constant(:MARKUP_TO_TAG, :NON_NAME_LINK_PATTERN, :NAME_LINK_PATTERN)
  # Convert __Names__ to links in a textile string.
  def convert_name_links_to_tagged_objects!
    @@name_lookup ||= {}

    # Look for __Name__ turn into "Name":name_id.
    # Look for "Name":name and fill in id.
    # Look for "Name":name_id and make sure id matches name just
    # in case the user changed the name without updating the id.
    gsub!(NAME_LINK_PATTERN) do |orig_str|
      prefix = $LAST_MATCH_INFO[:prefix]
      label = remove_formatting($LAST_MATCH_INFO[:formatted_label])
      name = strip_out_sp_cfr_and_sensu(
        supply_implicit_species(
          expand_genus_abbreviation(label)
        )
      )

      if (parse = Name.parse_name(name)) &&
         # Allowing arbitrary authors on Genera and higher makes it impossible
         # to distinguish between publication titles and taxa, e.g.,
         # "Lichen Flora of the Greater Sonoran Region".
         # I'm sure it can still break with species but it should be
         # very infrequent (I don't see it in current tests). -JPH
         (parse.author.blank? || parse.rank != "Genus")
        Textile.private_register_name(parse.real_text_name, parse.rank)
        "#{prefix}x{NAME __#{label}__ }{ #{name} }x"
      else
        orig_str
      end
    end
  end

  # Remove any formatting. This will be the "label" of the link.
  def remove_formatting(str)
    Name.clean_incoming_string(str.gsub(/[_*]/, ""))
  end

  # Expand abbreviated genus (but only if followed by species epithet!).
  # This will be sent to lookup_name.
  def expand_genus_abbreviation(str)
    str.sub(/^([A-Z])\.? +(?=["a-z])/) do |x|
      (n = @@name_lookup[Regexp.last_match(1)]) ? "#{n} " : x
    end
  end

  # Expand bare variety, etc.  For example, after using Amanita muscaria:
  #   _var alba_  -->  Amanita muscaria var. alba
  # (This is not perfect: if subspecies and varieties are mixed it can mess up.)
  def supply_implicit_species(str)
    if str.sub!(/^(subsp|ssp)\.? +/, "")
      expand_subspecies(str)
    elsif str.sub!(/^(var|v)\.? +/, "")
      expand_variety(str)
    elsif str.sub!(/^(forma?|f)\.? +/, "")
      expand_form(str)
    else
      str
    end
  end

  def expand_subspecies(str)
    @@last_species ? "#{@@last_species} subsp. #{str}" : ""
  end

  def expand_variety(str)
    if @@last_subspecies
      "#{@@last_subspecies} var. #{str}"
    else
      @@last_species ? "#{@@last_species} var. #{str}" : ""
    end
  end

  def expand_form(str)
    if @@last_variety
      "#{@@last_variety} f. #{str}"
    elsif @@last_subspecies
      "#{@@last_subspecies} f. #{str}"
    else
      @@last_species ? "#{@@last_species} f. #{str}" : ""
    end
  end

  # Allow a number of author-like syntaxes that aren't normally allowed.
  # Remove them and match the rest.  Examples:
  #   _Laccaria cf. laccata_     -->  Laccaria laccata
  #   _Parmelia s. lat/str._     -->  Parmelia
  def strip_out_sp_cfr_and_sensu(str)
    str.sub(/ cfr?\.? /, " ").
      sub(/ ((s|sensu)\.? ?(l|lato|s|str|stricto)\.?)$/, "").
      sub(/ sp\.$/, "")
  end

  OTHER_LINK_PATTERN = %r{
    (?<prefix> ^|\W)
    (?: _+)
    (?<marked_type>
      [a-zA-Z]+ # model name or abbr
      (?: _[a-zA-Z]+)? # optionally including underscores
    )
    \s+
    (?<id> [^_\s](?:[^_\n]+[^_\s])?) # id -- integer or string
    (?: _+)

    (?! (?: \w|</[a-z]+>)) # discard if trailed by word char or html close tag
  }x

  # Convert _object name_ and _object id_ to a textile string.
  def convert_other_links_to_tagged_objects!
    gsub!(OTHER_LINK_PATTERN) do |orig|
      prefix = $LAST_MATCH_INFO[:prefix]
      marked_type = $LAST_MATCH_INFO[:marked_type]
      id = $LAST_MATCH_INFO[:id]

      tagged_type = MARKUP_TO_TAG[marked_type.downcase.to_sym]
      next(orig) unless tagged_type

      label = tagged_object_label(marked_type, id)
      "#{prefix}x{#{tagged_type} __#{label}__ }{ #{id} }x"
    end
  end

  def tagged_object_label(type, id)
    (/^\d+$/.match?(id) ? "#{type} #{id}" : id)
  end

  # Convert !image 12345! in a textile string.
  def convert_embedded_image_links_to_textile!
    gsub!(%r{!image (?:(\w+)/)?(\d+)!}) do
      size = Regexp.last_match[1] || "thumb"
      id   = Regexp.last_match[2]
      src  = Image.url(size, id)
      link = "#{MO.http_domain}/images/#{id}"
      "\"!#{src}!\":#{link}"
    end
  end
  private_constant(:OTHER_LINK_PATTERN)

  def strip_caps_class_spans!
    gsub!(%r{((<span class="caps">[A-Z]+</span>)+)}) do |url|
      url.gsub(%r{<span class="caps">([A-Z]+)</span>}, '\\1')
    end
  end

  # Remove pre-existing links, replacing them with "<XXXnn>" while saving them.
  # Return array of saved links.
  def pre_existing_links_replaced_by_placeholders!(do_object_links)
    saved_links = []
    gsub!(%r{(<a[^>]*>.*?</a>|<img[^>]*>)}) do |href|
      if do_object_links
        href = href.gsub(/
          x\{([A-Z]+) \s+ ([^{}]+?) \s+\}\{\s+ ([^{}]+?) \s+\}x
        /x, '\\2')
      end
      saved_links.push(href)
      "<XXX#{saved_links.length - 1}>"
    end
    saved_links
  end

  # NOTE: (JDC 2023-06-23) Multiple lookbehinds are required because
  # Ruby does not allow variable length lookbehinds.
  # They might be avoided via the (nontrivial) changes suggested here:
  # https://github.com/MushroomObserver/mushroom-observer/pull/1528#issuecomment-1608114858
  # rubocop:disable Style/RegexpLiteral
  # cop gives false positive
  IMPLICIT_TERM_PATTERN = /
    (?<! x{NAME) # discard match if it follows MO internal object tag
    (?<! x{GLOSSARY_TERM)
    (?<! x{OBSERVATION)
    (?<! x{LOCATION)
    (?<! x{USER)
    (?<! x{IMAGE)
    (?<! x{PROJECT)
    (?<! x{SPECIES_LIST)
    (?<! x{COMMENT)

    (?<prefix> ^|\W) # prefix
    (?: _+)
    (?<id> (?: [\p{Latin}0-9\-.'’]+ \ ?){1,3}) # 1-3 words
    (?: _+)

    (?! (?: \w|<\/[a-z]+>)) # discard if followed by word char or close tag
  /x
  # rubocop:enable Style/RegexpLiteral
  private_constant(:IMPLICIT_TERM_PATTERN)

  def convert_implicit_terms_to_tagged_glossary_terms!
    gsub!(IMPLICIT_TERM_PATTERN) do
      id = $LAST_MATCH_INFO[:id]
      "#{$LAST_MATCH_INFO[:prefix]}" \
      "x{GLOSSARY_TERM __#{tagged_object_label("term", id)}__ }{ #{id} }x"
    end
  end

  ###############################

  def restore_pre_existing_links!(saved_links)
    gsub!(/<XXX(\d+)>/) do
      saved_links[Regexp.last_match(1).to_i].to_s.
        gsub(/ x\{ ([^{}]*) \}x /x, '\\1')
    end
  end

  def convert_bare_urls_to_links!
    gsub!(%r{([a-z]+://[^\s<>]+)}) do |url|
      extra = url.sub!(%r{([^\w/]+$)}, "") ? Regexp.last_match(1) : ""
      # Leave as much untouched as possible, but some characters will cause the
      # HTML to be badly formed, so escape them.
      url.gsub!(/([<>"\\]+)/) { CGI.escape(Regexp.last_match(1)) }
      "<a href=\"#{url}\">#{link_label(url)}</a>#{extra}"
    end
  end

  def link_label(url)
    return url unless truncate_link_label?(url)

    if url =~ %r{^(\w+://[^/]+)(.*?)$}
      "#{Regexp.last_match(1)}/..."
    else
      "#{url[0..URL_TRUNCATION_LENGTH]}..."
    end
  end

  def truncate_link_label?(url)
    url.length > URL_TRUNCATION_LENGTH && !url.starts_with?(MO.http_domain)
  end

  OBJECT_TAG_PATTERN = /
    x\{
        (?<type> [A-Z]+_?[A-Z]+)
        \s+
        (?<label> [^{}]+?)
        \s+
      \}
      \{
        \s+
        (?<id> [^{}]+?)
        \s+
      \}x
  /x
  private_constant(:OBJECT_TAG_PATTERN)

  def convert_tagged_objects_to_proper_links!
    gsub!(OBJECT_TAG_PATTERN) do |_orig|
      type = $LAST_MATCH_INFO[:type]
      label = $LAST_MATCH_INFO[:label]
      id = $LAST_MATCH_INFO[:id]
      id.gsub!(/&#821[6789];/, "'")
      id.gsub!(/&#822[01];/, '"')
      id = CGI.unescapeHTML(id)
      id = CGI.escape(id)
      url = "#{MO.http_domain}/lookups/lookup_#{type.downcase}/#{id}"

      "<a href=\"#{url}\">#{label}</a>"
    end
  end

  def fully_qualify_links!
    gsub!(%r{href="/}, "href=\"#{MO.http_domain}/")
  end
end
