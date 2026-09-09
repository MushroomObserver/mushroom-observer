# frozen_string_literal: true

# iNat logins are lowercase; normalize the stored value so comparisons
# against values from iNat match however the user typed it.
module NormalizesInatUsername
  def inat_username=(val)
    if val.is_a?(String)
      super(val.strip.downcase)
    else
      super
    end
  end
end
