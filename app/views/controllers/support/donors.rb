# frozen_string_literal: true

module Views::Controllers::Support
  # Donor wall — striped table of donor names.
  class Donors < Views::Base
    prop :donor_list, _Array(_Hash(::String, ::String))

    def view_template
      add_page_title(:donors_title.l)
      add_context_nav(::Tab::Support::DonorsActions.new(
                        admin: in_admin_mode?
                      ))

      div(class: "text-center") do
        table(class: "table-striped table-donors mt-3 mb-3") do
          @donor_list.each { |donor| tr { td { plain(donor["who"]) } } }
        end
      end
      trusted_html(:donors_order.tp)
    end
  end
end
