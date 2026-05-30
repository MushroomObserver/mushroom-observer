# frozen_string_literal: true

# Phlex form for `account/preferences#edit` — replaces the
# `account/preferences/edit.html.erb` `form_with` block and its 6
# section partials (_login, _privacy, _appearance, _filters, _notes,
# _email) + 3 filter sub-partials.
#
# Multiple submit buttons (one per section) preserve the pre-Phlex
# convenience that lets users save changes from any section without
# scrolling to the bottom of the page. The form's URL is the
# resource path (PATCH to `account_preferences_path`).
#
# Content-filter fields (`Query::Filter.all`) live under the
# `user[<filter_sym>]` namespace and read their `checked` /
# `value` state from `@user.content_filter[filter.sym]` rather
# than a direct model attribute. The controller's
# `update_content_filter` private method writes them back to the
# hash.
class Components::AccountPreferencesForm < Components::ApplicationForm
  # Email-section logic (EMAIL_GROUPS constant + two render methods)
  # lives in its own concern to keep this class under the
  # `Metrics/ClassLength` limit.
  include EmailSection

  def initialize(user, licenses:, **)
    @licenses = licenses
    super(user, id: "account_preferences_form", **)
  end

  def form_action
    account_preferences_path
  end

  def view_template
    render_login_section
    render_privacy_section
    render_appearance_section
    render_filters_section
    render_notes_section
    render_email_section
  end

  private

  # ====================================================================
  # Login
  # ====================================================================

  def render_login_section
    text_field(:login, prefs: true)
    text_field(:email, prefs: true)
    password_field(:password, label: "#{:prefs_password_new.t}:")
    password_field(:password_confirmation,
                   label: "#{:prefs_password_confirm.t}:")
    submit(:SAVE_EDITS.l, center: true)
  end

  # ====================================================================
  # Privacy
  # ====================================================================

  # Each Privacy select renders inline with a retroactive-trigger
  # addon via the input-group `:button` wrapper option. Two of the
  # three triggers are GET links to their respective edit pages —
  # they navigate AWAY from the prefs form and do NOT apply the
  # neighbouring select's value, so they open in a new tab and carry
  # a glyph + accessible title saying so. The filename-purge trigger
  # is the only in-page mutation, so it stays a same-tab PUT gated
  # by a turbo-confirm.
  def render_privacy_section
    div(class: "form-group mt-3 font-weight-bold") do
      plain(:prefs_privacy.t)
    end
    render_votes_anonymous_select
    render_keep_filenames_select
    render_license_id_select
    submit(:SAVE_EDITS.l, center: true)
  end

  def render_votes_anonymous_select
    addon = external_addon(:prefs_apply_to_votes.t,
                           images_edit_vote_anonymity_path)
    select_field(:votes_anonymous, anon_values, prefs: true, **addon)
  end

  def render_keep_filenames_select
    # Reuses the `:new_window` glyph the two external triggers carry,
    # even though this one doesn't navigate. The icon signals "this
    # click opens something" (in this case the turbo-confirm modal),
    # which softens the "destructive button" read. No `target=_blank`
    # / `rel` / new-tab `title` here — those would be lies.
    select_field(:keep_filenames, filename_values,
                 label: :prefs_keep_image_filenames.l,
                 button: :prefs_purge_filenames.t,
                 button_href: images_bulk_filename_purge_path,
                 button_class: addon_button_class,
                 button_icon: :new_window,
                 button_data: filename_purge_data)
  end

  def filename_purge_data
    { turbo_method: :put,
      turbo_confirm: :prefs_bulk_filename_purge_confirm.l }
  end

  def render_license_id_select
    addon = external_addon(:prefs_apply_to_images.t,
                           images_edit_licenses_path)
    select_field(:license_id, @licenses,
                 label: "#{:LICENSE.l}:", **addon) do |f|
      f.with_between { render_license_note }
    end
  end

  # Shared shape for the two GET retroactive triggers: button text +
  # href, opened in a new tab (rel-hardened), with a `new-window`
  # glyph + accessible tooltip so the new-tab signal isn't only
  # visual.
  def external_addon(text, href)
    { button: text, button_href: href, button_class: addon_button_class,
      button_target: "_blank", button_rel: "noopener noreferrer",
      button_title: :opens_in_new_tab.t, button_icon: :new_window }
  end

  def addon_button_class
    "btn btn-sm btn-outline-default"
  end

  def anon_values
    values = [
      [:prefs_votes_anonymous_no.l, :no],
      [:prefs_votes_anonymous_yes.l, :yes]
    ]
    # Pre-`vote_cutoff` users get the "grandfather old anonymous votes"
    # option so they can flip to public going forward without
    # retroactively de-anonymizing.
    if model.created_at && model.created_at < Time.zone.parse(MO.vote_cutoff)
      values << [:prefs_votes_anonymous_old.l(cutoff: MO.vote_cutoff), :old]
    end
    values
  end

  def filename_values
    [
      [:prefs_keep_image_filenames_toss.l, "toss"],
      [:prefs_keep_image_filenames_keep_but_hide.l, "keep_but_hide"],
      [:prefs_keep_image_filenames_keep_and_show.l, "keep_and_show"]
    ]
  end

  def render_license_note
    span(class: "help-note mr-3") do
      plain("(")
      trusted_html(:prefs_license_note.t)
      plain(")")
    end
  end

  # ====================================================================
  # Appearance
  # ====================================================================

  def render_appearance_section
    div(class: "form-group mt-3 font-weight-bold") do
      plain(:prefs_appearance.t)
    end
    render_appearance_text_selects
    render_appearance_obs_options
    render_appearance_image_selects
    submit(:SAVE_EDITS.l, center: true)
  end

  def render_appearance_text_selects
    select_field(:hide_authors, hide_authors_values,
                 prefs: true, inline: true)
    select_field(:location_format, location_format_values,
                 prefs: true, inline: true)
    select_field(:theme, theme_values, prefs: true, inline: true) do |f|
      f.with_append { render_theme_about_link }
    end
    select_field(:locale, locale_values, prefs: true, inline: true)
  end

  def render_appearance_obs_options
    checkbox_field(:thumbnail_maps, prefs: true)
    checkbox_field(:view_owner_id, prefs: true)
    number_field(:layout_count, prefs: true, class: "mt-3", inline: true)
  end

  def render_appearance_image_selects
    select_field(:image_size, image_size_values,
                 prefs: true, inline: true)
    select_field(:label_format, label_format_values,
                 prefs: true, inline: true)
  end

  def hide_authors_values
    [
      [:prefs_hide_authors_none.l, "none"],
      [:prefs_hide_authors_above_species.l, "above_species"]
    ]
  end

  def location_format_values
    [
      [:prefs_location_format_postal.l, "postal"],
      [:prefs_location_format_scientific.l, "scientific"]
    ]
  end

  def theme_values
    [[:theme_random.l, "RANDOM"]] + MO.themes.map { |t| [t.to_sym.l, t] }
  end

  def render_theme_about_link
    link_to(:prefs_themes_about.t, theme_color_themes_path,
            class: "ml-4")
  end

  def locale_values
    Language.all.map do |lang|
      name = lang.name
      name += " (beta)" if lang.beta
      [name, lang.locale]
    end
  end

  # Only show image sizes larger than `small` — small is the
  # display-size default so it's not interesting as a "show" choice.
  def image_size_values
    User.image_sizes.filter_map do |key, value|
      next unless value > User.image_sizes[:small]

      [:"image_show_#{key}".l, key]
    end
  end

  def label_format_values
    [
      [:prefs_label_format_pdf.l, "pdf"],
      [:prefs_label_format_rtf.l, "rtf"]
    ]
  end

  # ====================================================================
  # Filters
  # ====================================================================

  def render_filters_section
    div(class: "form-group mt-3") do
      span(class: "font-weight-bold") { plain(:prefs_content_filters.t) }
      # Two paragraphs: explanation, then a blank one to push the
      # first filter row down (the ERB this replaces had an unclosed
      # `<p>` after the explanation).
      p { plain(:prefs_content_filters_explanation.t) }
      p { nil }
    end
    Query::Filter.all.each do |filter| # rubocop:disable Rails/FindEach
      render_filter_field(filter)
    end
    submit(:SAVE_EDITS.l, center: true)
  end

  # Renders one content-filter field. Branches on the filter's
  # declared `type` + `prefs_vals` shape, mirroring the pre-Phlex
  # filters/_checkbox / _select / _text_field sub-partials.
  def render_filter_field(filter)
    case filter.type
    when :boolean
      render_boolean_filter(filter)
    when [:string]
      render_string_filter(filter)
    else
      raise("unrecognized content filter type #{filter.type.inspect}")
    end
  end

  def render_boolean_filter(filter)
    return if filter.prefs_vals.empty?

    if filter.prefs_vals.one?
      render_boolean_checkbox_filter(filter)
    else
      render_boolean_select_filter(filter)
    end
  end

  def render_boolean_checkbox_filter(filter)
    checkbox_field(filter.sym,
                   label: :"prefs_filters_#{filter.sym}".t,
                   checked: model.content_filter[filter.sym] ==
                            filter.prefs_vals.first)
  end

  def render_boolean_select_filter(filter)
    options = [[:prefs_filter_off.t, filter.off_val]] +
              filter.prefs_vals.map do |val|
                [:"prefs_filters_#{filter.sym}_#{val}".t, val]
              end
    select_field(filter.sym, options,
                 label: "#{:"prefs_filters_#{filter.sym}".t}:",
                 selected: model.content_filter[filter.sym],
                 inline: true)
  end

  def render_string_filter(filter)
    text_field(filter.sym,
               label: "#{:"prefs_filters_#{filter.sym}".t}:",
               value: model.content_filter[filter.sym]) do |f|
      f.with_between { render_string_filter_help(filter) }
    end
  end

  def render_string_filter_help(filter)
    div { trusted_html(:"prefs_filters_#{filter.sym}_help".t) }
  end

  # ====================================================================
  # Notes
  # ====================================================================

  def render_notes_section
    textarea_field(:notes_template, prefs: true, rows: 1) do |f|
      f.with_between { render_notes_help }
    end
    submit(:SAVE_EDITS.l, center: true)
  end

  def render_notes_help
    p(class: "help-note mr-3") do
      plain(:prefs_notes_template_explanation.t)
    end
  end
end
