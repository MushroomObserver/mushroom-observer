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

  # Latin-script locales where `.titleize` actually capitalizes every
  # word correctly, confirmed against real translated content: es, pt,
  # pl (plus en). Excludes French and Italian despite being
  # Latin-script -- both routinely use apostrophe-elided articles
  # ("d'activité", "d'attività"), and `.titleize`'s apostrophe
  # handling assumes English contraction suffixes, capitalizing the
  # letter right after the apostrophe ("D'activité") instead of
  # leaving it alone.
  TI_TITLEIZE_LOCALES = [:en, :es, :pt, :pl].freeze

  # Cyrillic/Greek locales: `.titleize`'s word-start regex is
  # ASCII-only, so it's a silent no-op here -- not even
  # sentence-casing. `String#capitalize` itself IS Unicode-aware
  # though, so `capitalize_each_word` below reproduces per-word
  # title-casing by hand. Confirmed against real translated content
  # that multi-word ALL-CAPS translations in these locales are
  # predominantly per-word-capitalized, the same convention as
  # English -- so this gets meaningfully closer to the stored text
  # than sentence-case would, even though (like `.titleize` itself)
  # it doesn't know which words are connectors/acronyms that a human
  # translator would leave alone.
  TI_WORD_CAPITALIZE_LOCALES = [:el, :ru, :uk, :be].freeze

  # Locale-aware title-casing shared by `ti` and the `[:tag.ti]`
  # embedded-ref syntax. `TI_TITLEIZE_LOCALES` get full title-case via
  # `.titleize`; `TI_TURKIC_LOCALES` and `TI_WORD_CAPITALIZE_LOCALES`
  # get the same per-word effect via `capitalize_each_word`;
  # everywhere else that has letter casing at all, only the first
  # letter is capitalized (sentence-case) -- which also sidesteps the
  # apostrophe bug the title-casing paths share, since only the very
  # first letter of the whole string is ever touched.
  def self.titleize_localized(str)
    locale = I18n.locale.to_sym
    return str.titleize if TI_TITLEIZE_LOCALES.include?(locale)
    return capitalize_each_word(str, turkic: true) if
      TI_TURKIC_LOCALES.include?(locale)
    return capitalize_each_word(str) if
      TI_WORD_CAPITALIZE_LOCALES.include?(locale)
    return str if TI_NO_OP_LOCALES.include?(locale)

    str.capitalize
  end

  # Capitalizes every run of letters in +str+, treating apostrophes
  # and hyphens as part of the word they're attached to (same
  # word-boundary behavior `.titleize` has, including its French/
  # Italian elision-prefix limitation -- which is why those two
  # locales aren't routed through this method either).
  def self.capitalize_each_word(str, turkic: false)
    str.gsub(/\p{Alpha}[\p{Alpha}'’-]*/) do |word|
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
