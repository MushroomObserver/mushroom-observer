class Symbol
  if !defined? old_localize
    alias :old_localize :localize
  end

  # Wrapper on the old localize method that:
  #   1) converts '\n' into newline throughout
  #   2) maps '[arg]' via optional hash you can pass in
  #
  # There are several related wrappers on localize:
  #   t    Textilize: no paragraphs or links or anything fancy.
  #   tl   Do 't' and check for links.
  #   tp   Wrap 't' in a <p> block.
  #   tpl  Wrap 't' in a <p> block AND do links.
  def localize(args={})
    result = Globalite.localize(self, "[:#{self}]", {})
    if result.is_a?(String)
      result = result.gsub(/ *\\n */, "\n")
      result = result.gsub('<<', '«')
      result = result.gsub('>>', '»')
      result = result.gsub(/\[([a-z_]+?)\]/) do
        unless args.has_key?($1.to_sym)
          raise(ArgumentError, "Forgot to pass :#{$1} into localization for :#{self}.")
        end
        args[$1.to_sym].to_s
      end if args.is_a?(Hash)
    else
      # raise(RuntimeError, "Globalite.localize(:#{self}) returned a #{result.class} = '#{result}'.")
    end
    result
  end
  alias :l :localize

  def t(*args); localize(*args).t; end
  def tl(*args); localize(*args).tl; end
  def tp(*args); localize(*args).tp; end
  def tpl(*args); localize(*args).tpl; end
end
