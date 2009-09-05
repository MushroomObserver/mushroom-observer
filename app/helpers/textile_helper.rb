
module ApplicationHelper
  # Override Rails method of the same name.  Just calls our String method of
  # the same name of the given string.
  def textilize_without_paragraph(str, do_object_links=false)
    str.to_s.textilize_without_paragraph(do_object_links)
  end

  # Override Rails method of the same name.  Just calls our String method of
  # the same name of the given string.
  def textilize(str, do_object_links=false)
    str.to_s.textilize(do_object_links)
  end
end

################################################################################

class String
  if !defined? SHOW_OBJECT_URLS
    SHOW_OBJECT_URLS = {
      'name' => '/name/show_name/%d',
      'user' => '/observer/show_user/%d',
      'image' => '/image/show_image/%d',
      'comment' => '/comment/show_comment/%d',
      'project' => '/project/show_project/%d',
      'location' => '/location/show_location/%d',
      'observation' => '/%d',
    }
  end

  URL_TRUNCATION_LENGTH = 60 if !defined? URL_TRUNCATION_LENGTH

  # Wrapper on string.textilize that returns only the body of the first
  # paragraph of the result.
  def textilize_without_paragraph(do_object_links=false)
    textilize(do_object_links).sub(/\A<p[^>]*>(.*?)<\/p>.*/m, '\\1')
  end

  # Textilizes the string using RedCloth, doing a little extra processing:
  #   1) it fixes long urls by turning them into links and abbreviating the
  #      text actually shown.
  #   2) converts _object_ constructs into appropriate links (unless told not to).
  #
  # There are a number of related methods and shorthand aliases:
  #   textilize                     The general case.
  #   textilize_without_paragraph   Just returns body of first paragraph.
  #   t                             Same as textilize_without_paragraph(false).
  #   tl                            Same as textilize_without_paragraph(true).
  #   tp                            Same as textilize(false).
  #   tpl                           Same as textilize(true).
  #
  # Here are some mnemonics for the aliases:
  #   t    Just textilize: no paragraphs or links or anything fancy.
  #   tl   Do 't' and check for links.
  #   tp   Wrap 't' in a <p> block.
  #   tpl  Wrap 't' in a <p> block AND do links.
  def textilize(do_object_links=false)
    str = self.clone

    # This converts the "_object blah_" constructs into "x{OBJECT id label}x".
    # (The "x"s prevent Textile from interpreting the curlies as style info.)
    if do_object_links
      str.check_name_links!
      str.check_other_links!
      str.check_our_images!
    end

    # Let Textile munge the thing up now.
    str = RedCloth.new(str).to_html

    # Remove pre-existing links first, replacing with "<XXXnn>".
    hrefs = []
    str.gsub!(/(<a[^>]*>.*?<\/a>|<img[^>]*>)/) do |href|
      if do_object_links
        href = href.gsub(/
          x\{ ([A-Z]+) (?:\s+ (\d+))? (?:\s+ ([^\{\}]+?))? \s*\}x
        /x) do
          $3 || ('%s #%d' % [$1.downcase.capitalize, $2 || 0] )
        end
      end
      hrefs.push(href)
      "<XXX#{hrefs.length - 1}>"
    end

    # Now turn bare urls into links.
    str.gsub!(/([a-z]+:\/\/[^\s<>]+)/) do |url|
      extra = url.sub!(/([^\w\/]+$)/, '') ? $1 : ''
      url2 = ''
      if url.length > URL_TRUNCATION_LENGTH and not url.starts_with?(DOMAIN)
        if url.match(/^(\w+:\/\/[^\/]+)(.*?)$/)
          url2 = $1 + '/...'
        else
          url2 = url[0..URL_TRUNCATION_LENGTH] + '...'
        end
      else
        url2 = url
      end
      # These are the only things that would really f--- things up.
      # ... and actually Textile doesn't let these things through, anyway.
      url = url.gsub(/"/, '%22').gsub(/</, '%3C').gsub(/>/, '%3E')
      "<a href=\"#{url}\">#{url2}</a>"
    end

    # Convert _object_ tags into proper links.
    if do_object_links
      str.gsub!(/
        x\{ ([A-Z]+) (?:\s+ (\d+))? (?:\s+ ([^\{\}]+?))? \s*\}x
      /x) do |orig|
        if url = SHOW_OBJECT_URLS[$1.downcase]
          type  = $1
          id    = $2 || 0
          label = $3 || ('%s #%d' % [type.downcase.capitalize, id])
          "<a href=\"#{url}\">%s</a>" % [id, label]
        else
          orig
        end
      end
    end

    # Put pre-existing links back in (removing the _object_ tag wrappers).
    str.gsub!(/<XXX(\d+)>/) do
      hrefs[$1.to_i].to_s.gsub(/ x\{ ([^\{\}]*) \}x /x, '\\1')
    end

    return str
  end

  def t; textilize_without_paragraph(false); end
  def tl; textilize_without_paragraph(true); end
  def tp; '<div class="textile">' + textilize(false) + '</div>'; end
  def tpl; '<div class="textile">' + textilize(true) + '</div>'; end

  # Register one or more name objects so that subsequent textile strings can
  # refer to them by abbreviation.
  def self.register_name(*names)
    for name in names
      if name && name.respond_to?('text_name') && !name.above_genus?
        @@textile_name_lookup ||= {}
        name.text_name.match(/([A-Z])/)
        @@textile_name_lookup[$1] = name
        @@textile_last_species    = name if name.rank == :Species
        @@textile_last_subspecies = name if name.rank == :Subspecies
        @@textile_last_variety    = name if name.rank == :Variety
      end
    end
  end

  def self.textile_name_size
    @@textile_name_lookup ||= {}
    @@textile_name_lookup.size
  end

  def self.clear_textile_cache
    @@textile_name_lookup = {}
  end

protected

  # Convert __Names__ to links in a textile string.
  def check_name_links!
    @@textile_name_lookup ||= {}

    # Look for __Name__ turn into "Name":name_id.  Look for "Name":name and
    # fill in id.  Look for "Name":name_id and make sure id matches name just
    # in case the user changed the name without updating the id.
    self.gsub!(/
      (^|\W) (?:\**_+)
        ( (?: "?[A-Z](?:[a-z\-]*|\.)"? (?: (?:\s+ (?:[a-z]+\.\s+)? "?[a-z\-]+"? )* | \s+ sp\. ) |
          (?:subsp|ssp|var|v|forma?|f)\.? \s+ "?[a-zë\-]+"? ) )
        ( \s+ (?: "?[^a-z"\s_] | in\s?ed\.? | auct\.? | van\sd[a-z]+\s[A-Z] | s[\.\s] | sensu\s ) [^_]* )?
      (?:_+\**) (?=(?:s|ish|like)?(?:\W|’|\Z))
    /x) do |orig|
      prefix = $1.to_s
      name   = $2.to_s
      author = $3.to_s

      # Remove any formatting.
      str1 = (name + author).gsub(/[_*]/, '')

      # Expand abbreviated genus (but only if followed by species epithet!).
      str2 = str1.sub(/^([A-Z])\.? +(?=["a-z])/) do |x|
        (n = @@textile_name_lookup[$1]) ? n.text_name.sub(/ .*/, '') + ' ' : x
      end

      # Expand bare variety, etc.  For example, after using Amanita muscaria:
      #   _var alba_  -->  Amanita muscaria var. alba
      # (This is not perfect: if subspecies and varieties are mixed it can mess up.)
      if str2.sub!(/^(subsp|ssp)\.? +/, '')
        str2 = @@textile_last_species    ? @@textile_last_species.text_name  + ' subsp. ' + str2 : ''
      elsif str2.sub!(/^(var|v)\.? +/, '')
        str2 = @@textile_last_subspecies ? @@textile_last_subspecies.text_name + ' var. ' + str2 :
               @@textile_last_species    ? @@textile_last_species.text_name    + ' var. ' + str2 : ''
      elsif str2.sub!(/^(forma?|f)\.? +/, '')
        str2 = @@textile_last_variety    ? @@textile_last_variety.text_name    + ' f. ' + str2 :
               @@textile_last_subspecies ? @@textile_last_subspecies.text_name + ' f. ' + str2 :
               @@textile_last_species    ? @@textile_last_species.text_name    + ' f. ' + str2 : ''
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

      # Look up name.
      name = nil
      if parse = Name.parse_name(str2)
        name = Name.find_by_search_name(parse[3]) ||
               Name.find_by_text_name(parse[0])
      end

      if name &&
        # Allowing arbitrary authors on Genera and higher makes it impossible to
        # distinguish between publication titles and taxa, e.g., "Lichen Flora
        # of the Greater Sonoran Region".  I'm sure it can still break with species
        # but it should be very infrequent (I don't see it in current tests). -JPH
        (author == '' || name.below_genus?)

        # Update which genus this first letter would mean in an abbrev.
        if !name.above_genus?
          name.text_name.match(/([A-Z])/)
          @@textile_name_lookup[$1] = name
          @@textile_last_species    = name if name.rank == :Species
          @@textile_last_subspecies = name if name.rank == :Subspecies
          @@textile_last_variety    = name if name.rank == :Variety
        end

        # Allow "sensu Authors" that aren't in database.  Example:
        #   _S. riparia sensu A.H.Smith_  -->  <a>**__S. riparia__**</a> __sensu A.H.Smith__
        if !name.author.to_s.match(/sensu/) && str2.sub!(/ (sensu .*)/ ,'')
          postfix = ' ' + $1 + postfix
        end

        # Format name starting with bare text_name (no "sp." or author).
        label = '__%s__' % name.text_name
        label = '**%s**' % label if !name.deprecated
        label.sub!(/([A-Z])[a-zë\-]*/, '\\1.') if str1.match(/^[A-Z]\.? /)
        label.gsub!(/ (var|subsp|f)\. /, '__ \\1. __')

        # Strip off all but author (and "sp.") from user's string.
        author = str2.split
        author = author[name.text_name.split.length .. author.length-1]
        author = author.empty? ? '' : ' ' + author.join(' ')
        prefix + 'x{NAME %d %s%s }x%s' % [name.id, label, author, postfix]
      else
        orig
      end
    end
  end

  # Convert _object name_ and _object id_ in a textile string.
  def check_other_links!
    self.gsub!(/
      (^|\W) (?:_+) ([a-z]+) \s+ ([^_\s](?:[^_\n]+[^_\s])?) (?:_+) (?!\w)
    /x) do |orig|
      prefix = $1
      type   = $2
      id     = $3
      str    = nil
      obj    = nil
      result = orig
      begin
        # Look up id if given name instead, e.g. _user jason_
        if id && id.match(/\D/)
          str = id
          case type
            when 'name':
              obj = Name.find_by_search_name(str) ||
                    Name.find_by_text_name(str)
              id = obj.id if obj

            when 'user':
              obj = User.find_by_login(str) ||
                    User.find_by_name(str)
              id = obj.id if obj

            when 'location':
              pattern = str.downcase.gsub(/\W+/, '%')
              ids = Location.connection.select_values %(
                SELECT id FROM locations
                WHERE LOWER(locations.search_name) LIKE '%#{pattern}%'
              )
              id = ids.first if ids.length == 1
          end
        end

        # Look up object and create label for it.
        case type
          when 'comment':
            obj ||= Comment.find(id)
            
          when 'image':
            obj ||= Image.find(id)

          when 'location':
            obj ||= Location.find(id)

          when 'name':
            obj ||= Name.find(id)
            str ||= obj.display_name.sub(name.author, '')

          when 'observation':
            obj ||= Observation.find(id)

          when 'project':
            obj ||= Project.find(id)
            str ||= obj.title

          when 'species_list':
            obj ||= SpeciesList.find(id)

          when 'user':
            obj ||= User.find(id)
            str ||= obj.login
        end

        # Only create link for approved objects that actually exist.
        if obj
          result = type.upcase
          result += ' ' + id.to_s
          result += ' ' + str.gsub('{','&#123;').gsub('}','&#125;') if str
          result = prefix + 'x{' + result + ' }x'
        end
      rescue
      end
      result
    end
  end

  # Convert !image 12345! in a textile string.
  def check_our_images!
    self.gsub!(/!image (\d+)!/) do
      '"!/images/thumb/%d.jpg!":/image/show_image/%d' % [$1, $1]
    end
  end
end
