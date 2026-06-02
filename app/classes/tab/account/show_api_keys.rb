# frozen_string_literal: true

# "API keys" account-management link.
class Tab::Account::ShowAPIKeys < Tab::Base
  def title
    :account_api_keys_link.t
  end

  def path
    account_api_keys_path
  end
end
