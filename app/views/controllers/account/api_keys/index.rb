# frozen_string_literal: true

# Action template for `Account::APIKeysController#index` — the
# "manage your API keys" page. Page chrome plus a textile-rendered
# help block plus the `APIKeys::Table` of the user's keys.
#
module Views::Controllers::Account::APIKeys
  class Index < Views::FullPageBase
    prop :user, ::User

    def view_template
      add_page_title(:account_api_keys_title.t)
      add_context_nav(Tab::Account::APIActions.new)
      container_class(:full)

      Container(width: :text) do
        ContentPadded { trusted_html(:account_api_keys_help.tp) }
      end

      render(Table.new(user: @user))
    end
  end
end
