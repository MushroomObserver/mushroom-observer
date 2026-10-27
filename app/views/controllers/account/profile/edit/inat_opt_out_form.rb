# frozen_string_literal: true

# The Danger Zone checkbox that stops imports of the user's iNat
# observations' images and notes.
module Views::Controllers::Account::Profile
  class Edit::InatOptOutForm < ::Components::ApplicationForm
    def initialize(model, **)
      super(model, method: :patch, id: "inat_opt_out_form", **)
    end

    def view_template
      super do
        checkbox_field(:inat_import_opt_out, label: :profile_inat_opt_out.l)
        submit(:save.ti)
      end
    end

    def form_action
      account_inat_opt_out_path
    end
  end
end
