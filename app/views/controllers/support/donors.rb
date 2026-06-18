# frozen_string_literal: true

module Views::Controllers::Support
  # Donor wall — striped table of donor names.
  class Donors < Views::FullPageBase
    prop :donor_names, _Array(::String)

    def view_template
      add_page_title(:donors_title.l)
      add_context_nav(::Tab::Support::DonorsActions.new(
                        admin: in_admin_mode?
                      ))

      div(class: "text-center") do
        table(class: "table-striped table-donors mt-3 mb-3") do
          @donor_names.each { |name| tr { td { plain(name) } } }
        end
      end
      trusted_html(:donors_order.tp)
    end
  end
end
