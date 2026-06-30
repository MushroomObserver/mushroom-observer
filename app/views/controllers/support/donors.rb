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
        render(Components::Table.new(@donor_names,
                                     variant: :striped,
                                     identifier: "donors",
                                     class: "mt-3 mb-3",
                                     show_headers: false)) do |t|
          t.column(nil) { |name| plain(name) }
        end
      end
      trusted_html(:donors_order.tp)
    end
  end
end
