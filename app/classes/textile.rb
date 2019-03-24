# frozen_string_literal: true.

require "cgi"
require "redcloth"

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

  #########@ Class methods #####################################################

  # Convenience wrapper on instance method Textile#textilize_without_paragraph.
  def self.textilize_without_paragraph(str, do_object_links = false,
                                       sanitize = true)
    new(str).textilize_without_paragraph(do_object_links, sanitize)
  end

  # Wrap self.textilize_without_paragraph, marking output trusted safe
  def self.textilize_without_paragraph_safe(str, do_object_links = false,
                                            sanitize = true)
    textilize_without_paragraph(str, do_object_links, sanitize).
      # Disable cop; we need `html_safe` to prevent Rails from adding escaping
      html_safe # rubocop:disable Rails/OutputSafety
  end

  # Convenience wrapper on the instance method Textile#textilize.
  def self.textilize(str, do_object_links = false, sanitize = true)
    new(str).textilize(do_object_links, sanitize)
  end

  # Wrap self.textilize_without_paragraph, marking output trusted safe
  def self.textilize_safe(str, do_object_links = false, sanitize = true)
    textilize(str, do_object_links, sanitize).
      # Disable cop; we need `html_safe` to prevent Rails from adding escaping
      html_safe # rubocop:disable Rails/OutputSafety
  end

  #########@ Instance methods ##################################################

  # Wrapper on textilize that returns only the body of the first paragraph of
  # the result.
  def textilize_without_paragraph(do_object_links = false, sanitize = true)
    textilize(do_object_links, sanitize).sub(%r{\A<p[^>]*>(.*?)</p>.*}m, '\\1')
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
  def textilize(do_object_links = false, sanitize = true)
    # This converts the "_object blah_" constructs into "x{OBJECT id label}x".
    # (The "x"s prevent Textile from interpreting the curlies as style info.)
    if do_object_links
      check_name_links!
      check_other_links!
      check_our_images!
    end

    # Textile will screw with "@John Doe@".  We need to protect at signs now.
    gsub!("@", "&#64;")

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
    convert_object_tags_to_proper_links!
    fully_qualify_links!
    restore_pre_existing_links!(saved_links)

    self
  end

  # Register one or more names (instances) so that subsequent textile strings
  # can refer to them by abbreviation.
  def self.register_name(*names)
    names.each do |name|
      next unless name.try(:at_or_below_genus?)

      Textile.private_register_name(name.real_text_name, name.rank)
    end
  end

  def self.private_register_name(name, rank)
    @@name_lookup ||= {}
    @@name_lookup[Regexp.last_match(1)] = name.split.first if name =~ /([A-Z])/
    if rank == :Species
      @@last_species    = name
      @@last_subspecies = nil
      @@last_variety    = nil
    elsif rank == :Subspecies
      @@last_species    = name.sub(/ ssp\. .*/, "")
      @@last_subspecies = name
      @@last_variety    = nil
    elsif rank == :Variety
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

  NAME_LINK_PATTERN = /
    (^|\W) (?:\**_+) ([^_]+) (?:_+\**) (?= (?:s|ish|like)? (?:\W|\Z) )
  /x.freeze
  OTHER_LINK_PATTERN = /
   (^|\W) (?:_+) ([a-zA-Z]+) \s+ ([^_\s](?:[^_\n]+[^_\s])?) (?:_+) (?!\w)
  /x.freeze

  # Convert __Names__ to links in a textile string.
  def check_name_links!
    @@name_lookup ||= {}

    # Look for __Name__ turn into "Name":name_id.  Look for "Name":name and
    # fill in id.  Look for "Name":name_id and make sure id matches name just
    # in case the user changed the name without updating the id.
    gsub!(NAME_LINK_PATTERN) do |orig_str|
      prefix = Regexp.last_match(1)
      label = remove_formatting(Regexp.last_match(2))
      name = expand_genus_abbreviation(label)
      name = supply_implicit_species(name)
      name = strip_out_sp_cfr_and_sensu(name)
      if (parse = Name.parse_name(name)) &&
         # Allowing arbitrary authors on Genera and higher makes it impossible
         # to distinguish between publication titles and taxa, e.g.,
         # "Lichen Flora of the Greater Sonoran Region".
         # I'm sure it can still break with species but it should be
         # very infrequent (I don't see it in current tests). -JPH
         (parse.author.blank? || parse.rank != :Genus)
        Textile.private_register_name(parse.real_text_name, parse.rank)
        prefix + "x{NAME __#{label}__ }{ #{name} }x"
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
      (n = @@name_lookup[Regexp.last_match(1)]) ? n + " " : x
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

  # Convert _object name_ and _object id_ in a textile string.
  def check_other_links!
    gsub!(OTHER_LINK_PATTERN) do |orig|
      result = orig
      prefix = Regexp.last_match(1)
      type = Regexp.last_match(2)
      id = Regexp.last_match(3)
      matches = [
        ["comment"],
        %w[image img],
        %w[location loc],
        ["name"],
        %w[observation obs ob],
        %w[project proj],
        %w[species_list spl],
        ["user"]
      ].select { |x| x[0] == type.downcase || x[1] == type.downcase }
      if matches.length == 1
        label = (/^\d+$/.match?(id) ? "#{type} #{id}" : id)
        result =
          "#{prefix}x{#{matches.first.first.upcase} __#{label}__ }{ #{id} }x"
      end
      result
    end
  end

  # Convert !image 12345! in a textile string.
  def check_our_images!
    gsub!(%r{!image (?:(\w+)/)?(\d+)!}) do
      size = Regexp.last_match[1] || "thumb"
      id   = Regexp.last_match[2]
      src  = Image.url(size, id)
      link = "#{MO.http_domain}/image/show_image/#{id}"
      "\"!#{src}!\":#{link}"
    end
  end

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
          x\{([A-Z]+) \s+ ([^\{\}]+?) \s+\}\{\s+ ([^\{\}]+?) \s+\}x
        /x, '\\2')
      end
      saved_links.push(href)
      "<XXX#{saved_links.length - 1}>"
    end
    saved_links
  end

  def restore_pre_existing_links!(saved_links)
    gsub!(/<XXX(\d+)>/) do
      saved_links[Regexp.last_match(1).to_i].to_s.
        gsub(/ x\{ ([^\{\}]*) \}x /x, '\\1')
    end
  end

  def convert_bare_urls_to_links!
    gsub!(%r{([a-z]+:\/\/[^\s<>]+)}) do |url|
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
      Regexp.last_match(1) + "/..."
    else
      url[0..URL_TRUNCATION_LENGTH] + "..."
    end
  end

  def truncate_link_label?(url)
    url.length > URL_TRUNCATION_LENGTH && !url.starts_with?(MO.http_domain)
  end

  def convert_object_tags_to_proper_links!
    gsub!(/
      x\{([A-Z]+) \s+ ([^\{\}]+?) \s+\}\{\s+ ([^\{\}]+?) \s+\}x
    /x) do |_orig|
      type = Regexp.last_match(1)
      label = Regexp.last_match(2)
      id = Regexp.last_match(3)
      id.gsub!(/&#822[01];/, '"')
      id = CGI.unescapeHTML(id)
      id = CGI.escape(id)
      url = "#{MO.http_domain}/observer/lookup_#{type.downcase}/#{id}"
      "<a href=\"#{url}\">#{label}</a>"
    end
  end

  def fully_qualify_links!
    gsub!(%r{href="/}, "href=\"#{MO.http_domain}/")
  end
end
