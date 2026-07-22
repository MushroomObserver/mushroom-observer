# frozen_string_literal: true

# "Cancel iNat import and create observation manually" link.
class Tab::InatImport::Cancel < Tab::Base
  def title
    :cancel_and_create.t(type: :observation)
  end

  def path
    new_observation_path
  end
end
