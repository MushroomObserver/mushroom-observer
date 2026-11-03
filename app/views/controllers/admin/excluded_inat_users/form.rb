# frozen_string_literal: true

# Adds an iNat login to the excluded iNat users list.
module Views::Controllers::Admin::ExcludedInatUsers
  class Form < ::Components::ApplicationForm
    def initialize(model, **)
      super(model, method: :post, id: "excluded_inat_user_form", **)
    end

    def view_template
      super do
        text_field(:inat_login, label: :excluded_inat_user_login.l)
        textarea_field(:reason, label: :excluded_inat_user_reason.l, rows: 2)
        submit(:add.ti)
      end
    end

    def form_action
      admin_excluded_inat_users_path
    end
  end
end
