# frozen_string_literal: true

# Action template for `Account::APIKeysController#edit` — the no-JS
# fallback for editing an API key (JS users edit inline on the
# index). Page chrome plus help text plus the shared form.
#
module Views::Controllers::Account::APIKeys
  class Edit < Views::FullPageBase
    prop :key, ::APIKey

    def view_template
      add_page_title(:account_api_keys_title.t)
      add_context_nav(Tab::Account::APIActions.new)
      trusted_html(:account_api_keys_help.tp)
      # Stays local: true (Turbo-off): see the comment in new.rb --
      # same no-JS fallback, same turbo_stream-target mismatch.
      render(Form.new(
               @key,
               action: account_api_key_path(id: @key.id),
               id: "account_edit_api_key_form",
               local: true
             ))
    end
  end
end
