# frozen_string_literal: true

module Name::Format
  GROUP_AT_END_OF_TEXT_NAME = / #{Name::Parse::GROUP_ABBR}$/
  # When we `include` a module, the way to add class methods is like this:
  def self.included(base)
    base.extend(ClassMethods)
  end

  ##### Display of names ######################################################

  # `user` lets us respect the viewer's hide_authors pref (nil => no
  # viewer-specific transform, raw stored value).
  def display_name(user = nil)
    str = self[:display_name]
    if user &&
       user.hide_authors == "above_species" &&
       Name.ranks_above_species.include?(rank)
      str = str.sub(/^(\**__.*__\**).*/, '\\1')
    end
    str
  end

  # Alias for +display_name+ to be consistent with other objects.
  def format_name(user = nil)
    display_name(user)
  end

  # Tack id on to end of +format_name+.
  def unique_format_name(user = nil)
    string_with_id(display_name(user))
  end

  def unique_search_name
    string_with_id(search_name)
  end

  # (This gives us the ability to format names slightly differently when
  # applied to observations.  For example, we might tack on "sp." to some
  # higher-ranked taxa here.)
  def observation_name(user = nil)
    display_name(user)
  end

  # Marked up Name, authors shortened per ICN Recommendation 46C.2,
  #  e.g.: **__"Xxx yyy__ author1 et al.**
  def display_name_brief_authors(user = nil)
    if rank == "Group"
      # Xxx yyy group author
      display_name(user).sub(/ #{Regexp.quote(author)}$/,
                             " #{brief_author}")
    else
      # Xxx yyy author, Xxx sect. yyy author, Xxx author sect. yyy
      # Relies on display_name having markup around name proper
      # Otherwise, it might delete author if that were part of the name proper
      display_name(user).sub(/(\*+|_+) #{Regexp.quote(author)}/,
                             "\\1 #{brief_author}")
    end
  end

  # display_name less author
  # This depends on display_name having markup around name proper
  # Otherwise, it might delete author if that were part of the name proper
  def display_name_without_authors(user = nil)
    if rank == "Group"
      # Remove author and preceding space at end
      display_name(user).sub(/ #{Regexp.quote(author)}$/, "")
    else
      # Remove author and preceding space after markup
      display_name(user).sub(/(\*+|_+) #{Regexp.quote(author)}/, "\\1 ").
        strip_squeeze
    end
  end

  # Tack id on to end of +text_name+.
  def unique_text_name(user = nil)
    string_with_id(real_text_name(user))
  end

  def real_text_name(user = nil)
    Name.display_to_real_text(self, user)
  end

  def real_search_name(user = nil)
    Name.display_to_real_search(self, user)
  end

  # Page heading (rendered HTML — textile applied + author wrapping).
  # `user` arg lets us respect hide_authors prefs. When nil we use the
  # raw display_name (no user-specific transforms).
  def page_title(user = nil)
    display_name(user).t.small_author
  end

  # Plain-text title for the browser tab `<title>`. Helper prepends
  # the type-tag + id; `text_name` is the binomial-only column.
  # (Can't `alias` to AR column from a module — accessor not in
  # scope at class-load.)
  def document_title
    text_name
  end

  def sensu_stricto
    text_name.sub(GROUP_AT_END_OF_TEXT_NAME, "")
  end

  # Is this the "unknown" name?
  def unknown?
    text_name == "Fungi"
  end

  def known?
    !unknown?
  end

  def imageless?
    text_name == "Imageless"
  end

  ##### Miscellaneous #########################################################

  # Info to include about each name in merge requests.
  def merge_info
    num_obs     = observations.count
    num_namings = namings.count
    num_notify  = interests.count # includes name_trackers
    "#{:NAME.l} ##{id}: #{real_search_name} [#obs: #{num_obs}, " \
      "#namings: #{num_namings}, #users_with_interest: #{num_notify}]"
  end

  #############################################################################

  private

  PROV                       = /[a-z]+\.? prov\.?|ined\.?|ad ?int\.?/
  INVAL                      = /[a-z]+\.? (inval|illeg(it)?)\.?/
  ANY_ENDING_AFTER_COMMA     = /^(.*)(, [a-z. ]+)$/
  SOME_ENDINGS_WITHOUT_COMMA = /^(.*)( (#{PROV}|#{INVAL}))$/
  ENDINGS_WORTH_KEEPING      = / (#{PROV}|#{INVAL})$/
  private_constant(:PROV, :INVAL, :ANY_ENDING_AFTER_COMMA,
                   :SOME_ENDINGS_WITHOUT_COMMA, :ENDINGS_WORTH_KEEPING)

  # author(s) string shortened per ICN Recommendation 46C.2
  # Relies on name.author having a comma only if there are > 2 authors
  def brief_author
    str = author
    # pull of any qualifiers at the end, like "ined.", "nom. prov.", etc.
    if (match = author.match(ANY_ENDING_AFTER_COMMA) ||
                author.match(SOME_ENDINGS_WITHOUT_COMMA))
      str, ending = match[1, 2]
      ending = "" unless ending.match(ENDINGS_WORTH_KEEPING)
    end
    str.sub(/,.*\)/, " et al.)"). # shorten > 2 authors in parens
      sub(/,.*/, " et al.") +     # then shorten any remaining > 2 authors
      ending.to_s                 # tack qualifiers back onto end
  end

  module ClassMethods
    def display_to_real_text(name, user = nil)
      name.display_name(user).
        gsub(/(_\*?\*?)[^_*]*$/, '\1'). # Remove trailing author
        gsub(/__\*?\*? [^_*]* \s (#{Name::Parse::ANY_NAME_ABBR}) \s \*?\*?__/ox,
             ' \1 '). # Remove internal author
        gsub(/\*?\*?__\*?\*?/, ""). # Remove textile ornamentation
        concat(group_suffix(name, user)) # Readd group suffix
    end

    def display_to_real_search(name, user = nil)
      name.display_name(user).gsub(/\*?\*?__([^_]+)__\*?\*?/, '\1')
    end

    def group_suffix(name, user = nil)
      Name::Parse::GROUP_CHUNK.match(name.display_name(user)).to_s
    end

    # Make sure display names are in boldface for accepted names, and not in
    # boldface for deprecated names.
    def make_sure_names_are_bolded_correctly(dry_run: false)
      msgs = []
      needs_fixing = Name.deprecated.
                     where(Name[:display_name].matches("%*%")).
                     or(Name.not_deprecated.
                        where(Name[:display_name].does_not_match("%*%")))
      needs_fixing.each do |name|
        unless dry_run
          name.change_deprecated(name.deprecated)
          name.save
        end
        msgs << "The name #{name.search_name.inspect} " \
                "should #{name.deprecated && "not "}have been in boldface."
      end
      msgs
    end

    ##### Names treated specially #############################################

    # Array of strings that mean "unknown" in the local language:
    #
    #   "unknown", ""
    #
    def names_for_unknown
      ["unknown", :unknown.l, ""]
    end

    # Get an instance of the Name that means "unknown".
    def unknown
      Name.find_by(text_name: "Fungi")
    end
  end
end
