# frozen_string_literal: true

# Action template for `Account::APIKeysController#new` — the no-JS
# fallback for creating an API key (JS users use the inline collapse
# panel on the index). Page chrome + help text + the shared form.
#
# Replaces `app/views/controllers/account/api_keys/new.html.erb`.
module Views::Controllers::Account::APIKeys
  class New < Views::FullPageBase
    prop :key, ::APIKey

    def view_template
      add_page_title(:account_api_keys_title.t)
      add_context_nav(Tab::Account::APIActions.new)
      trusted_html(:account_api_keys_help.tp)
      render(Form.new(
               @key,
               action: account_api_keys_path,
               id: "new_api_key_form"
             ))
    end
  end
end
