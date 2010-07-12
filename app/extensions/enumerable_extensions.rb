#
#  = Extensions to Enumerable
#  == Methods
#
#  select_rand::    Pick a random value from among the allowed values.
#
################################################################################

module Enumerable

  # Pick a random value from among the allowed values.
  def select_rand
    tmp = self.to_a
    tmp[Kernel.rand(tmp.size)]
  end
end
