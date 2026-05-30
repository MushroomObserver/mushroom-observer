# frozen_string_literal: true

require("test_helper")

class AccountPreferencesFormTest < ComponentTestCase
  def setup
    super
    @user = users(:rolf)
    User.current = @user
  end

  # ---- Form scaffolding ----

  def test_form_action_and_method
    html = render_form

    assert_html(html, "form#account_preferences_form")
    assert_html(html,
                "form#account_preferences_form[action='#{prefs_path}']")
    assert_html(html, "form#account_preferences_form[method='post']")
    # Rails patch-via-hidden-field convention.
    assert_html(html, "input[type='hidden'][name='_method'][value='patch']")
  end

  # ---- Section 1: Login ----

  def test_login_section_renders_four_fields_plus_submit
    html = render_form

    assert_html(html, "input[type='text'][name='user[login]'][value='rolf']")
    assert_html(html, "input[type='text'][name='user[email]']")
    # Password fields default to empty value so the existing hash never
    # round-trips through the browser.
    assert_html(html, "input[type='password'][name='user[password]'][value='']")
    assert_html(html, "input[type='password']" \
                      "[name='user[password_confirmation]'][value='']")
    # Each section has its own submit button (one of 6).
    assert_html(html, "input[type='submit'][value='#{:SAVE_EDITS.l}']")
  end

  # ---- Section 2: Privacy ----

  def test_privacy_section_renders_anon_filename_license_selects
    html = render_form

    assert_html(html, "select[name='user[votes_anonymous]']")
    assert_html(html, "select[name='user[keep_filenames]']")
    assert_html(html, "select[name='user[license_id]']")
    # License note is HTML-safe textile that includes a link to the
    # help-page anchor. Pre-conversion ERB used `tag.span(safe_join)`
    # to keep the `<a>` from being escaped; the Phlex view does the
    # same via `trusted_html`.
    assert_html(html, ".help-note a[href*='how_to_use#license']")
  end

  def test_privacy_grandfather_anonymous_option_for_pre_cutoff_users
    @user.created_at = Time.zone.parse(MO.vote_cutoff) - 1.day
    html = render_form

    # Pre-cutoff users can keep old anonymous votes grandfathered while
    # picking "public going forward".
    assert_html(html,
                "select[name='user[votes_anonymous]'] option[value='old']")
  end

  def test_privacy_no_grandfather_anonymous_option_for_post_cutoff_users
    @user.created_at = Time.zone.parse(MO.vote_cutoff) + 1.day
    html = render_form

    assert_no_html(html,
                   "select[name='user[votes_anonymous]'] option[value='old']")
  end

  # ---- Section 3: Appearance ----

  def test_appearance_section_renders_selects_checkboxes_and_layout_count
    html = render_form

    assert_html(html, "select[name='user[hide_authors]']")
    assert_html(html, "select[name='user[location_format]']")
    assert_html(html, "select[name='user[theme]']")
    # Theme has an "About Themes" link rendered via the with_append slot.
    assert_html(html, "a[href='/theme/color_themes']")
    assert_html(html, "select[name='user[locale]']")
    assert_html(html,
                "input[type='checkbox'][name='user[thumbnail_maps]']")
    assert_html(html, "input[type='checkbox'][name='user[view_owner_id]']")
    assert_html(html,
                "input[type='number'][name='user[layout_count]'][min='1']")
    assert_html(html, "select[name='user[image_size]']")
    assert_html(html, "select[name='user[label_format]']")
  end

  # ---- Section 4: Content filters ----

  def test_filters_section_renders_one_field_per_query_filter
    html = render_form

    Query::Filter.all.each do |filter| # rubocop:disable Rails/FindEach
      next if filter.type == :boolean && filter.prefs_vals.empty?

      # Every filter that has prefs_vals gets a form control named
      # `user[<sym>]`. Don't pin the exact tag — checkbox vs select vs
      # text_field is per-filter.
      assert_html(html, "[name='user[#{filter.sym}]']")
    end
  end

  def test_string_filter_renders_help_div
    html = render_form

    string_filter = Query::Filter.all.find { |f| f.type == [:string] }
    skip("no string filter configured") unless string_filter

    # The filter help is `:prefs_filters_<sym>_help.t`, HTML-safe textile
    # with smart quotes — Phlex must `trusted_html` it, not `plain`.
    assert_includes(html, :"prefs_filters_#{string_filter.sym}_help".t)
  end

  # ---- Section 5: Notes ----

  def test_notes_section_renders_textarea_with_help
    html = render_form

    assert_html(html, "textarea[name='user[notes_template]'][rows='1']")
    # Help paragraph sits inline between label and textarea via the
    # `with_between` slot.
    assert_html(html, "p.help-note", text: :prefs_notes_template_explanation.l)
  end

  # ---- Section 6: Email ----

  def test_email_section_renders_grouped_checkboxes_and_html_note
    html = render_form

    assert_html(html, "h5", text: :prefs_email_prefs.l)
    assert_html(html, "input[type='checkbox'][name='user[no_emails]']")
    assert_html(html, "input[type='checkbox'][name='user[email_html]']")
    # Five group headers, one per `EMAIL_GROUPS` entry.
    [:prefs_email_comments, :prefs_email_observations,
     :prefs_email_names, :prefs_email_locations,
     :prefs_email_general].each do |label_key|
      assert_includes(html, label_key.l)
    end
    # All grouped checkboxes render.
    [:email_comments_owner, :email_comments_response,
     :email_observations_consensus, :email_observations_naming,
     :email_names_admin, :email_names_author,
     :email_names_editor, :email_names_reviewer,
     :email_locations_admin, :email_locations_author,
     :email_locations_editor,
     :email_general_feature, :email_general_commercial,
     :email_general_question].each do |sym|
      assert_html(html, "input[type='checkbox'][name='user[#{sym}]']")
    end
    # Closing textile note at the bottom of the section.
    assert_html(html, "div.help-block.mt-4")
  end

  # ---- Multiple submits ----

  def test_six_submit_buttons_one_per_section
    html = render_form

    # Each of login, privacy, appearance, filters, notes, email has
    # its own submit so users don't have to scroll to the bottom.
    assert_html(html, "input[type='submit']", count: 6)
  end

  private

  def render_form
    licenses = License.available_names_and_ids(@user&.license)
    render(Components::AccountPreferencesForm.new(@user, licenses: licenses))
  end

  def prefs_path
    Rails.application.routes.url_helpers.account_preferences_path
  end
end
