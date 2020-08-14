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

  def add_leaf(*args)
    Tree.add_leaf(self, *args)
  end

  def has_node?(*args)
    Tree.has_node?(self, *args)
  end

  # Return a list of missing tags we've encountered.
  def self.missing_tags
    @@missing_tags = [] unless defined?(@@missing_tags)
    @@missing_tags
  end

  # Reset the list of missing tags.
  def self.missing_tags=(tags)
    @@missing_tags = tags
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
      @@missing_tags << self if defined?(@@missing_tags)
      if args.any?
        pairs = []
        for k, v in args
          pairs << "#{k}=#{v.inspect}"
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
      result = result.gsub(/\[\[/, "[").gsub(/\]\]/, "]")
    end
    if capitalize_result
      # Make token attempt to capitalize result if requested [:TAG] for :tag.
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
        val.is_a?(Symbol) ? "#{val}s".to_sym.l : val.to_s.strip_html

      # Want :TYPE, given :type.
      elsif args.key?(arg = x.downcase.to_sym) &&
            (x == x.upcase)
        val = args[arg]
        if val.is_a?(Symbol)
          val.to_s.upcase.to_sym.l
        else
          val.to_s.strip_html.upcase_first
        end

      # Want :TYPES, given :type.
      elsif args.key?(arg = y.downcase.to_sym) &&
            (y == y.upcase)
        val = args[arg]
        if val.is_a?(Symbol)
          "#{val.to_s.upcase}S".to_sym.l
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
          "#{val}s".to_sym.l.upcase_first
        else
          val.to_s.strip_html.upcase_first
        end

      else
        "[#{orig}]"
      end
    end
  end

  def localize_recursive_expansion(val, args, level) # :nodoc:
    val.gsub(/ \[ :(\w+?) (?:\( ([^\(\)\[\]]+) \))? \] /x) do
      tag = Regexp.last_match(1).to_sym
      args2 = Regexp.last_match(2).to_s
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
      tag.l(hash, level + [self])
    end
  end

  alias l localize

  def t(*args)
    localize(*args).t(false)
  end

  def tl(*args)
    localize(*args).tl(false)
  end

  def tp(*args)
    localize(*args).tp(false)
  end

  def tpl(*args)
    localize(*args).tpl(false)
  end

  def strip_html(*args)
    localize(*args).strip_html
  end
end
