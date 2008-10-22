
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
    str.gsub!(/(href=["'][^"']*["']|<img[^>]*>)/) do |href|
      hrefs.push(href)
      "<XXX#{hrefs.length - 1}>"
    end

    # Now turn bare urls into links.
    str.gsub!(/([a-z]+:\/\/[^\s<>]+)/) do |url|
      extra = url.sub!(/([^\w\/]+$)/, '') ? $1 : ''
      if url.length > 30
        if url.match(/^(\w+:\/\/[^\/]+)(.*?)$/)
          url2 = $1 + '/...'
        else
          url2 = url[0..30] + '...'
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
          id    = $2
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
  def tp; textilize(false); end
  def tpl; textilize(true); end

  # Register one or more name objects so that subsequent textile strings can
  # refer to them by abbreviation.
  def self.register_name(*names)
    for name in names
      if name && name.respond_to?('text_name') && !name.above_genus?
        @@textile_name_lookup ||= {}
        name.text_name.match(/([A-Z])/)
        @@textile_name_lookup[$1] = name
      end
    end
  end

protected

  # Convert __Names__ to links in a textile string.
  def check_name_links!
    @@textile_name_lookup ||= {}

    # Look for __Name__ turn into "Name":name_id.  Look for "Name":name and
    # fill in id.  Look for "Name":name_id and make sure id matches name just
    # in case the user changed the name without updating the id.
    self.gsub!(/
      (?:\**_+) ( "?[A-Z](?:[a-z\-]*|\.)"? (?: (?:\s+ (?:[a-z]+\.\s+)? "?[a-z\-]+"? )* | \s+ sp\.) ) (?:_+\**)
    /x) do |orig|
      # Remove any formatting.
      str1 = ($1 || $2).gsub(/[_*]/, '')

      # Expand abbreviated genus.
      str2 = str1.sub(/^([A-Z])\.? /) do |x|
        (n = @@textile_name_lookup[$1]) ? n.text_name.sub(/ .*/, ' ') : x
      end

      # Look up name.
      name = nil
      if parse = Name.parse_name(str2)
        name = Name.find_by_search_name(parse[3]) ||
               Name.find_by_text_name(parse[0])
      end

      # Update which genus this first letter would mean in an abbrev.
      if name && !name.above_genus?
        name.text_name.match(/([A-Z])/)
        @@textile_name_lookup[$1] = name
      end

      # Attempt to impose the correct formatting.
      if name
        str3 = name.display_name
        str3 = str3.sub(/([A-Z])[a-zë\-]*/, '\\1.') if str1 != str2
        str3 = str3.sub(name.author, '').strip if name.author && !str1.include?(name.author)
        'x{NAME %d %s }x' % [name.id, str3]
      else
        orig
      end
    end
  end

  # Convert _object name_ and _object id_ in a textile string.
  def check_other_links!
    self.gsub!(/
      (?:_+) ([a-z]+) \s+ ([^_\s](?:[^_\n]+[^_\s])?) (?:_+)
    /x) do |orig|
      begin
        type = $1
        id   = $2
        str  = nil

        if id && id.match(/\D/)
          str = id
          obj = case type
            when 'name':
              Name.find_by_search_name(str) ||
              Name.find_by_text_name(str)

            when 'user':
              User.find_by_login(str) ||
              User.find_by_name(str)

            when 'location':
              pattern = str.downcase.gsub(/\W+/, '%')
              ids = Location.connection.select_values %(
                SELECT id FROM locations
                WHERE LOWER(locations.search_name) LIKE '%#{pattern}%'
              )
              id = ids.first if ids.length == 1
              nil
          end
          id = obj.id if obj
        end

        if id && !str
          str = begin
            case type
              when 'name':
                name = Name.find(id)
                name.display_name.sub(name.author, '')

              when 'user':
                User.find(id).login

              when 'project':
                Project.find(id).title
            end
          end
        end

        result = type.upcase
        result += ' ' + id.to_s if id
        result += ' ' + str.gsub('{','&123;').gsub('}','&125;') if str
        'x{' + result + ' }x'
      rescue
        orig
      end
    end
  end

  # Convert !image 12345! in a textile string.
  def check_our_images!
    self.gsub!(/!image (\d+)!/) do
      "!/images/thumb/#{$1}.jpg!"
    end
  end
end
