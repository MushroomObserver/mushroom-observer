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
      # Stays local: true (Turbo-off): this is the explicit no-JS
      # fallback. Turbo-enabling it would make its POST always
      # request a turbo_stream response (Drive adds that Accept
      # header unconditionally for non-safe methods), which
      # Account::APIKeysController#create only knows how to satisfy
      # by replacing #account_api_keys_table -- an element that only
      # exists on the index page, not here. Silent no-op on submit.
      render(Form.new(
               @key,
               action: account_api_keys_path,
               id: "new_api_key_form",
               local: true
             ))
    end
  end
end
