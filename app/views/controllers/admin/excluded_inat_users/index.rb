# frozen_string_literal: true

# The admins' list of excluded iNat users (#5521): the add form, then a
# row per entry with its photo-deletion control and remove button.
module Views::Controllers::Admin::ExcludedInatUsers
  class Index < Views::FullPageBase
    prop :excluded, ::ExcludedInatUser
    prop :entries, _Array(::ExcludedInatUser)
    prop :purges, _Hash(String, ::ContentPurge)

    def view_template
      add_page_title(:excluded_inat_users_title.l)
      p { plain(:excluded_inat_users_help.l) }
      render(Form.new(@excluded, turbo: true))
      render(Table.new(entries: @entries, purges: @purges))
    end
  end
end
