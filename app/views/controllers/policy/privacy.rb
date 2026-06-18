# frozen_string_literal: true

module Views::Controllers::Policy
  # Privacy policy — static textile copy organized into header /
  # content sections plus a definitions table.
  class Privacy < Views::FullPageBase
    DEFINITIONS = [
      [:privacy_mo_inc_say,          :privacy_mo_inc_mean],
      [:privacy_mo_website_say,      :privacy_mo_website_mean],
      [:privacy_you_say,             :privacy_you_mean],
      [:privacy_this_policy_say,     :privacy_this_policy_mean],
      [:privacy_contributions_say,   :privacy_contributions_mean],
      [:privacy_personal_info_say,   :privacy_personal_info_mean],
      [:privacy_third_party_say,     :privacy_third_party_mean]
    ].freeze

    POST_TABLE_SECTIONS = [
      :privacy_covers_header,
      :privacy_covers_content,
      :privacy_types_of_information_header,
      :privacy_public_contributions,
      :privacy_account_info,
      :privacy_location_info,
      :privacy_usage_info,
      :privacy_when_we_share_info_header,
      :privacy_when_we_share_info_content,
      :privacy_how_we_protect_header,
      :privacy_how_we_protect_content,
      :privacy_how_long_do_we_keep_data_header,
      :privacy_how_long_do_we_keep_data_content,
      :privacy_where_is_mo_header,
      :privacy_where_is_mo_content,
      :privacy_do_not_track_header,
      :privacy_do_not_track_content,
      :privacy_changes_header,
      :privacy_changes_content,
      :privacy_contact_us_header,
      :privacy_contact_us_content,
      :privacy_thank_you_header,
      :privacy_thank_you_content,
      :privacy_last_modified
    ].freeze

    def view_template
      add_page_title(:privacy_title.l)

      trusted_html(:privacy_last_modified.tp)
      trusted_html(:privacy_intro_header.tp)
      trusted_html(:privacy_intro_content.tp)
      trusted_html(:privacy_definitions_header.tp)
      trusted_html(:privacy_definitions_content.tp)
      render_definitions_table
      POST_TABLE_SECTIONS.each { |k| trusted_html(k.tp) }
    end

    private

    def render_definitions_table
      table(class: "table table-striped") do
        render_definitions_header
        DEFINITIONS.each { |s, m| render_definitions_row(s, m) }
      end
    end

    def render_definitions_header
      tr do
        th(width: "33%") { trusted_html(:privacy_when_we_say.t) }
        th { b { trusted_html(:privacy_we_mean.t) } }
      end
    end

    def render_definitions_row(say_key, mean_key)
      tr do
        td { trusted_html(say_key.t) }
        td { trusted_html(mean_key.t) }
      end
    end
  end
end
