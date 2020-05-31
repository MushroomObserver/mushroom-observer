# frozen_string_literal: true

#
#  = Extensions to Integer
#
#  == Instance Methods
#
#  alphabetize::    Turn into base-62 "number"
#                   using upper and lowercase letters for digits over 9.
#
class Integer
  # Turn into base-62 "number" using upper and lowercase letters for digits
  # over 9.  You can also pass in alternate alphabets to achieve any base.  The
  # inverse is available as a method of String.
  #
  #   string = integer.alphabetize
  #   integer = string.dealphabetize
  #   #   0         -> 0
  #   #   42        -> g
  #   #   123456789 -> 8M0kX
  #
  #   hex = decimal.alphabetize('0123456789ABCDEF')
  #   decimal = hex.dealphabetize('0123456789ABCDEF')
  #   #   0         -> 0
  #   #   42        -> 2A
  #   #   123456789 -> 75BCD15
  #
  BASE62 = "0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz"

  def alphabetize(alphabet = BASE62)
    str      = ""
    num      = self
    alphabet = alphabet.to_s
    len      = alphabet.length
    while num.positive?
      x = num % len
      num = (num - x) / len
      str = alphabet[x, 1] + str
    end
    str == "" ? "0" : str
  end
end
