# frozen_string_literal: true

# Action template for `Account::APIKeysController#new` — the no-JS
# fallback for creating an API key (JS users use the inline collapse
# panel on the index). Page chrome + help text + the shared form.
#
module Views::Controllers::Account::APIKeys
  class New < Views::FullPageBase
    prop :key, ::APIKey

    def view_template
      add_page_title(:account_api_keys_title.t)
      add_context_nav(Tab::Account::APIActions.new)
      trusted_html(:account_api_keys_help.tp)
      # Form's full_page_form hidden field makes #create redirect here
      # instead of responding turbo_stream.
      render(Form.new(
               @key,
               action: account_api_keys_path,
               id: "new_api_key_form",
               turbo: true
             ))
    end
  end
end
