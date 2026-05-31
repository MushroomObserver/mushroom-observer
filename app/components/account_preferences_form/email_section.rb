# frozen_string_literal: true

# Email-prefs subsection of the account preferences form. Extracted
# from `Components::AccountPreferencesForm` (which is `include`d
# back) so the main form class stays under the
# `Metrics/ClassLength` limit and the email-specific data /
# rendering lives next to its `EMAIL_GROUPS` constant.
module Components::AccountPreferencesForm::EmailSection
  # Five `[group_heading_key, [field_syms...]]` pairs. Each entry
  # renders a "Group Name: (please notify)" heading row followed by
  # one checkbox per field. Order matches the pre-Phlex partial.
  EMAIL_GROUPS = [
    [:prefs_email_comments,
     [:email_comments_owner, :email_comments_response]],
    [:prefs_email_observations,
     [:email_observations_consensus, :email_observations_naming]],
    [:prefs_email_names,
     [:email_names_admin, :email_names_author,
      :email_names_editor, :email_names_reviewer]],
    [:prefs_email_locations,
     [:email_locations_admin, :email_locations_author,
      :email_locations_editor]],
    [:prefs_email_general,
     [:email_general_feature, :email_general_commercial,
      :email_general_question]]
  ].freeze

  def render_email_section
    h5(class: "mt-4 font-weight-bold") { plain(:prefs_email_prefs.t) }
    checkbox_field(:no_emails, prefs: true)
    checkbox_field(:email_html, prefs: true)
    EMAIL_GROUPS.each do |(label_key, fields)|
      render_email_group(label_key, fields)
    end
    div(class: "help-block mt-4") { trusted_html(:prefs_email_note.tp) }
    submit(:SAVE_EDITS.l, center: true)
  end

  def render_email_group(label_key, fields)
    div(class: "mt-4") do
      plain("#{label_key.t}: ")
      span(class: "help-note mr-3") do
        plain("(")
        trusted_html(:prefs_email_please_notify.t)
        plain(")")
      end
    end
    fields.each { |field| checkbox_field(field, prefs: true) }
  end
end
