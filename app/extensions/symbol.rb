# frozen_string_literal: true

#
#  = Extensions to Symbol
#  == Instance Methods
#
#  localize:: Wrapper on I18n#localize.
#  l::           Alias for localize.
#  t::           Localize, textilize (no paragraphs or obj links).
#  tl::          Localize, textilize with obj links (no paragraphs).
#  tp::          Localize, textilize with paragraphs (no obj links).
#  tpl::         Localize, textilize with paragraphs and obj links.
#  ti::          Localize, then title-case the result (no textilizing).
#
#  upcase_first  Capitalize 1st letter of Symbol, leaving remainder alone
#
################################################################################
#
class Symbol
  @raise_errors = false

  def self.raise_errors(turn_on = true)
    @raise_errors = turn_on
  end

  def self.raise_error?
    @raise_errors
  end

  # Capitalizes just the first letter of Symbol, leaving remainder alone
  # (Symbol#capitalize capitalizes first letter, downcases the rest)
  def upcase_first
    to_s.upcase_first.to_sym
  end

  def add_leaf(*)
    Tree.add_leaf(self, *)
  end

  def has_node?(*)
    Tree.has_node?(self, *)
  end

  # Return a list of missing tags we've encountered. A class-level
  # instance variable (not `@@`, which trips Style/ClassVars) -
  # matches the @raise_errors pattern just above. Test-only: every
  # setter/reader lives under test/ (test_helper.rb, session_extensions.rb),
  # and in production the setter is never called, so this is never
  # touched concurrently outside a single-threaded test worker - no
  # Concurrent::Array needed.
  def self.missing_tags
    @missing_tags ||= []
  end

  # Reset the list of missing tags.
  class << self
    attr_writer :missing_tags
  end

  # Does this tag have a translation?
  def has_translation?
    (I18n.t("#{MO.locale_namespace}.#{self}", default: "BOGUS_DEFAULT") !=
      "BOGUS_DEFAULT") ||
      (I18n.t("#{MO.locale_namespace}.#{downcase}", default: "BOGUS_DEFAULT") !=
        "BOGUS_DEFAULT")
  end

  # Wrapper on the old +localize+ method that:
  # 1. converts '\n' into newline throughout
  # 2. maps '[arg]' via optional hash you can pass in
  # 3. expands recursively-embedded tags like '[:tag]' and '[:tag(:key=val)]'
  #    or '[:tag1(:key=>:tag2)]' (but no deeper).
  #
  # There are several related wrappers on localize:
  # t::   Textilize: no paragraphs or links or anything fancy.
  # tl::  Do "t" and check for links.
  # tp::  Wrap "t" in a <p> block.
  # tpl:: Wrap "t" in a <p> block AND do links.
  #
  # Note that these are guaranteed to be "sanitary".
  # The strings in the translation
  # files are assumed to be same, even if they contain HTML.
  # Strings passed in via the '[arg]' syntax have any HTML stripped from them.
  #
  # ==== Argument expansion
  #
  # It supports some limited attempts to get case and number correct.  This
  # feature only works if the value passed in is a Symbol.  For example:
  #
  #   :tag.l(:type => :login)
  #
  #   # Given these definitions:
  #   LOGIN: Nombre de Usuario
  #   login: nombre de usuario
  #   LOGINS: Nombres de Usuario
  #   logins: nombres de usuario
  #
  #   # Yields these:
  #   tag1: Por favor, entrar [type]   =>  Por favor, entrar nombre de usuario
  #   tag2: Ningun [types] encontrados =>  Ningun nombres de usuario encontrados
  #   tag3: [Type] desaparecidos       =>  Nombre de usuario desaparecidos
  #   tag4: [Types] son necesarios     =>  Nombres de usuario son necesarios
  #   title1: Cambio de [TYPE]         =>  Cambio de Nombre de Usuario
  #   title2: Todos los [TYPES]        =>  Todos los Nombres de Usuario
  #
  # This allows German to capitalize all of the above, since all major nouns
  # are capitalized even in normal sentences.  And it allows the translator to
  # use plural if it makes more sense in their language, even if we used
  # singular in English.  And it allows translators to feel free to place a
  # word at the beginning of the sentece even if we didn't in English.
  #
  # *NOTE*: No case is enforced on literal Strings passed in, such as, for
  # example, user or observation names.
  #
  # ==== Recursively-Embedded Tags::
  #
  # Tag definitions are allowed to embed references to other tags.
  #
  #   [:alpha]
  #   [:alpha(alpha=almost_anything,alpha=almost_anything,...)]
  #
  # Where "almost_anything" is anything but , = () [] or \n.  If it looks like
  # a symbol (i.e. is ":alpha"), then it is converted into one.  If it is just
  # alphanumeric, then it is assumed to be an arg from the parent's hash.
  # Otherwise it must start and end with single-quotes.  Any additional single
  # quotes inside are preserved as-is.
  #
  #   [:tag(type=:name)]                 ==  :tag.l(type: :name)
  #   [:tag(type=parent_arg)]            ==  :tag.l(type: args[:parent_arg])
  #   [:tag(type='Literal Value')]       ==  :tag.l(type: "Literal Value")
  #   [:tag(type=""Quote's Are Kept"")]  ==  :tag.l(type: ""Quote"s Are Kept'")
  #
  # *NOTE*: Square brackets are NOT allowed in the literals, even if quoted!
  # That would make the parsing non-trivial and potentially slow.
  #
  def localize(args = {}, level = [])
    result = nil
    Language.note_usage_of_tag(self)
    if (val = I18n.t("#{MO.locale_namespace}.#{self}", default: "")) != ""
      result = localize_postprocessing(val, args, level)
    elsif (val = I18n.t("#{MO.locale_namespace}.#{downcase}",
                        default: "")) != ""
      result = localize_postprocessing(val, args, level, :captialize)
    else
      if Symbol.instance_variable_defined?(:@missing_tags)
        Symbol.missing_tags << self
      end
      if args.any?
        pairs = args.map do |k, v|
          "#{k}=#{v.inspect}"
        end
        args_str = "(#{pairs.join(",")})"
      else
        args_str = ""
      end
      result = "[:#{self}#{args_str}]"
    end
    # (I guess some "factory-installed" translations can actually return
    # Hashes instead of strings.  Don't ask me.  This just prevents it from
    # crashing in those cases at least.)
    result.is_a?(Hash) ? "".html_safe : result.html_safe
  end

  # Run +localize+ in test mode.
  def self.test_localize(val, args = {}, level = [])
    :test.localize_postprocessing(val, args, level)
  end

  def localize_postprocessing(val, args, level, capitalize_result = false)
    result = val
    if result.is_a?(String)
      result = result.gsub(/ *\\n */, "\n")
      if args.is_a?(Hash)
        result = localize_expand_arguments(result, args, level)
      end
      if level.length < 8
        result = localize_recursive_expansion(result, args, level)
      end
    end
    if result.is_a?(String)
      # Allow literal square brackets by doubling them.
      result = result.gsub("[[", "[").gsub("]]", "]")
    end
    if capitalize_result
      # Make token attempt to capitalize result if requested [:tag] for :tag.
      result = result.upcase_first
    end
    result
  end

  def localize_expand_arguments(val, args, _level) # :nodoc:
    val.gsub(/\[(\[?\w+?)\]/) do
      orig = x = y = Regexp.last_match(1)

      # Ignore double-brackets.
      if x[0, 1] == "["
        x

      # Want :type, given :type.
      elsif args.key?(arg = x.to_sym)
        val = args[arg]
        val.is_a?(Symbol) ? val.l : val.to_s.strip_html

      # Want :types, given :type.
      elsif (y = x.sub(/s$/i, "")) &&
            args.key?(arg = y.to_sym)
        val = args[arg]
        val.is_a?(Symbol) ? :"#{val}s".l : val.to_s.strip_html

      # Want :TYPE, given :type.
      elsif args.key?(arg = x.downcase.to_sym) &&
            (x == x.upcase)
        val = args[arg]
        if val.is_a?(Symbol)
          val.to_s.downcase.to_sym.ti
        else
          val.to_s.strip_html.upcase_first
        end

      # Want :TYPES, given :type.
      elsif args.key?(arg = y.downcase.to_sym) &&
            (y == y.upcase)
        val = args[arg]
        if val.is_a?(Symbol)
          :"#{val.to_s.downcase}s".ti
        else
          val.to_s.strip_html.upcase_first
        end

      # Want :Type, given :type.
      elsif args.key?(arg = x.downcase.to_sym)
        val = args[arg]
        if val.is_a?(Symbol)
          val.l.upcase_first
        else
          val.to_s.strip_html.upcase_first
        end

      # Want :Types, given :type.
      elsif args.key?(arg = y.downcase.to_sym)
        val = args[arg]
        if val.is_a?(Symbol)
          :"#{val}s".l.upcase_first
        else
          val.to_s.strip_html.upcase_first
        end

      else
        "[#{orig}]"
      end
    end
  end

  def localize_recursive_expansion(val, args, level) # :nodoc:
    val.gsub(/ \[ :(\w+?) (\.ti)? (?:\( ([^()\[\]]+) \))? \] /x) do
      tag = Regexp.last_match(1).to_sym
      titleize = Regexp.last_match(2).present?
      args2 = Regexp.last_match(3).to_s
      hash = args.dup
      if args2.present?
        args2.split(",").each do |pair|
          if pair =~ /^:?([a-z]+)=(.*)$/
            key = Regexp.last_match(1).to_sym
            val = Regexp.last_match(2).to_s
            if val =~ /^:(\w+)$/
              val = Regexp.last_match(1).to_sym
            elsif val.match(/^"(.*)"$/) ||
                  val.match(/^'(.*)'$/) ||
                  val.match(/^(-?\d+(\.\d+)?)$/)
              val = Regexp.last_match(1)
            elsif !val.match(/^([a-z][a-z_]*\d*)$/) && Symbol.raise_error?
              raise(ArgumentError.new("Invalid argument value \":#{val}\" in " \
                    "#{I18n.locale} localization for " +
                    ([self] + level).map(&:inspect).join(" --> ")))
            elsif !args.key?(val.to_sym) && Symbol.raise_error?
              raise(ArgumentError.new("Forgot to pass :#{val} into " \
                    "#{I18n.locale} localization for " +
                    ([self] + level).map(&:inspect).join(" --> ")))
            else
              val = args[val.to_sym]
            end
            hash[key] = val
          elsif Symbol.raise_error?
            raise(ArgumentError.new("Invalid syntax at \"#{pair}\" in " \
                  "arguments for #{I18n.locale} tag :#{tag} embedded in " +
                  ([self] + level).map(&:inspect).join(" --> ")))
          end
        end
      end
      result = tag.l(hash, level + [self])
      titleize ? Symbol.titleize_localized(result) : result
    end
  end

  alias l localize

  def t(*)
    localize(*).t(false)
  end

  def tl(*)
    localize(*).tl(false)
  end

  def tp(*)
    localize(*).tp(false)
  end

  def tpl(*)
    localize(*).tpl(false)
  end

  # Locales with no letter-casing concept at all -- capitalize/titleize
  # are meaningless there, and a stray Latin/Cyrillic substring (e.g.
  # an embedded species name) could get destructively downcased by
  # `.capitalize`, same risk as German below.
  TI_CASELESS_LOCALES = [:ar, :fa, :zh, :jp].freeze

  # German capitalizes every noun regardless of sentence position, so
  # translators already store the finished, correctly-capitalized
  # string as the base translation -- an audit of 280 comparable
  # ALL-CAPS/lowercase tag pairs found 178 byte-for-byte identical.
  # `.capitalize` would be destructive here (it downcases everything
  # after the first letter, breaking embedded capitalized nouns).
  TI_NO_OP_LOCALES = (TI_CASELESS_LOCALES + [:de]).freeze

  # Turkish's i/I case-mapping is locale-specific (dotted/dotless);
  # `.capitalize(:turkic)` handles it correctly. Applying :turkic
  # universally breaks every other locale's words starting with "i"
  # ("Image" -> "İmage"). Audited against real translated content:
  # 42 twin-pair tags matched a per-word title-case derivation vs. 15
  # for sentence-case, so Turkish joins the word-capitalize family
  # too, just with :turkic mapping applied per word instead of plain
  # `.capitalize`.
  TI_TURKIC_LOCALES = [:tr].freeze

  # Locales where translators predominantly write multi-word ALL-CAPS
  # content as per-word title-case, confirmed against real translated
  # content (#4844 deviation audit against a production checkpoint).
  # Everyone here goes through `capitalize_each_word`, never Rails'
  # `.titleize` -- `.titleize`'s word-start regex (`[a-z]`) is
  # ASCII-only, so it silently fails to capitalize any word starting
  # with an accented letter (í, ó, ą, ź, etc.), and its plural-acronym
  # handling ("IDs") needs a dedicated inflection just to work at all.
  # `capitalize_each_word` has neither problem: `String#capitalize` is
  # Unicode-aware, and its own acronym handling (see below) needs no
  # config. `en` was on `.titleize` until it wasn't -- once `at`/`by`/
  # `or` were confirmed as English's own connector-word exceptions
  # (same pattern as es/pt's "de"), there was no remaining reason for
  # English to be the one locale on a different code path. `pl`/`ru`
  # are deliberately NOT here: the same audit showed the opposite for
  # them, dominated by sentence-case (67%/68% of their deviations),
  # confirmed further by a same-tag cross-reference against `uk`
  # showing zero counter-examples -- they're in the sentence-case
  # default below instead.
  TI_WORD_CAPITALIZE_LOCALES = [:en, :es, :pt, :el, :uk, :be].freeze

  # Small connector words (articles, prepositions, conjunctions) that
  # stay lowercase in title case, same as standard English style-guide
  # convention. Never applies to a word's own first position -- see
  # `first` below.
  TI_LOWERCASE_WORDS = {
    en: %w[at by or with and].freeze,
    # "el" here is the Spanish definite article, not the :el (Greek)
    # locale symbol -- coincidental overlap, no functional collision
    # (this is a value in the :es array, not a locale key).
    es: %w[a con de del el la las los o para por].freeze,
    pt: %w[a as com da das de do dos e em o os ou para por].freeze,
    el: %w[στο στις εκ ή].freeze,
    uk: %w[в].freeze
  }.freeze

  # Locale-aware title-casing shared by `ti` and the `[:tag.ti]`
  # embedded-ref syntax. `TI_TURKIC_LOCALES` and
  # `TI_WORD_CAPITALIZE_LOCALES` get per-word title-case via
  # `capitalize_each_word`; everywhere else that has letter casing at
  # all, only the first letter is capitalized (sentence-case) -- which
  # also sidesteps the apostrophe bug title-casing shares, since only
  # the very first letter of the whole string is ever touched.
  def self.titleize_localized(str)
    locale = I18n.locale.to_sym
    return capitalize_each_word(str, turkic: true) if
      TI_TURKIC_LOCALES.include?(locale)
    return capitalize_each_word(str) if
      TI_WORD_CAPITALIZE_LOCALES.include?(locale)
    return str if TI_NO_OP_LOCALES.include?(locale)

    capitalize_first_letter_only(str)
  end

  # Capitalizes just the first letter, leaving the rest of +str+
  # exactly as stored -- unlike `String#capitalize`, which also
  # downcases everything after the first letter. That downcasing
  # destroys an embedded acronym the lowercase tag already stores
  # correctly whenever it isn't the very first word (confirmed against
  # real content: Polish's `icn_id` tag stores `"ICN Identyfikator"`,
  # and plain `.capitalize` was flattening it to `"Icn identyfikator"`,
  # lowercasing "ICN" and destroying "Identyfikator" along with it).
  # Same "translators already store correct casing" premise as
  # `TI_NO_OP_LOCALES` -- sentence-case only needs to add the one
  # letter of capitalization the lowercase tag doesn't already have.
  def self.capitalize_first_letter_only(str)
    return str if str.empty?

    str[0].upcase + str[1..]
  end

  # Capitalizes every run of letters in +str+, treating apostrophes,
  # hyphens, and parentheses as part of the word they're attached to
  # (same word-boundary behavior `.titleize` has, including its
  # French/Italian elision-prefix limitation -- which is why those two
  # locales aren't routed through this method either). Parentheses
  # matter for grammatical-gender suffix notation, e.g. Portuguese
  # "editor(a)"/"editores(as)" -- without them, the lone letter inside
  # the parens gets matched as its own "word" and capitalized
  # ("Editor(A)"), which is wrong; keeping it attached to the
  # preceding word means only the word's own first letter is ever
  # touched. A word that already has an uppercase letter past its
  # first position is left untouched instead of being run through
  # `.capitalize` -- which
  # would downcase everything after the first letter, destroying a
  # real acronym the lowercase tag already stores correctly. Confirmed
  # against real content across nearly every word-capitalize locale:
  # fully-uppercase acronyms ("API key" -> ours was flattening this to
  # "Api Key"; same for "ICN", "OK", "ДНК") and mixed-case ones too
  # ("IDs" -> ours was flattening this to "Ids"). No acronym config
  # needed -- if the lowercase tag already capitalized a letter that
  # isn't the word's first, that's a deliberate signal to leave it
  # alone. Applies `TI_LOWERCASE_WORDS` exceptions to any non-first
  # word.
  def self.capitalize_each_word(str, turkic: false)
    exceptions = TI_LOWERCASE_WORDS[I18n.locale.to_sym] || []
    first = true
    str.gsub(/\p{Alpha}[\p{Alpha}'’()-]*/) do |word|
      was_first = first
      first = false
      next word if word[1..].each_char.any? { |c| c != c.downcase }
      next word.downcase if !was_first && exceptions.include?(word.downcase)

      turkic ? word.capitalize(:turkic) : word.capitalize
    end
  end

  # Localize, then title-case the result for the current locale (see
  # `titleize_localized`). No textilizing: title-cased tags are short
  # UI labels, never Textile-formatted body text, and some callers
  # interpolate the result straight into an HTML attribute (e.g. a
  # `title:`) where inserted markup would be wrong. Use this instead
  # of authoring a separate ALL-CAPS twin tag for a title-cased
  # presentation of an existing lowercase tag.
  def ti(*)
    Symbol.titleize_localized(localize(*))
  end

  def strip_html(*)
    localize(*).strip_html
  end
end
