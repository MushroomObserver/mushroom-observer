# frozen_string_literal: true

# iNat logins are lowercase; see NormalizesInatUsername.
module NormalizesInatLogin
  def inat_login=(val)
    if val.is_a?(String)
      super(val.strip.downcase)
    else
      super
    end
  end
end
