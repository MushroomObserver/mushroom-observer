#
#  = Extensions to Fixnum
#
#  == Instance Methods
#
#  alphabetize::    Turn into base-62 "number" using upper and lowercase letters for digits over 9.
#
################################################################################

class Fixnum
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
  def alphabetize(alphabet="0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz")
    str      = ''
    num      = self
    alphabet = alphabet.to_s
    len      = alphabet.length
    while num > 0
      x = num % len
      num = (num - x) / len
      str = alphabet[x,1] + str
    end
    str = '0' if str == ''
    return str
  end
end
