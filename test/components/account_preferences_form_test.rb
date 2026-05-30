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

  def test_privacy_section_renders_three_retroactive_buttons_inline
    html = render_form

    # All three retroactive triggers are now `<a>`s rendered inside
    # the Privacy section via the related select's `with_append` slot
    # — not `button_to` forms sitting outside the prefs `<form>`.
    # The visual styling (`.btn.btn-sm.btn-outline-default`) is not
    # asserted: contract-only assertions here keep the tests stable
    # through the upcoming Bootstrap upgrade.

    # Vote anonymity: plain GET to the edit page. The pre-Phlex
    # `put_button` pointed at the PUT update URL with an unmatched
    # `commit` param and always flashed an error — fixed by routing
    # through the edit page that has its own "Make Public" button.
    assert_html(html, "a[href='/images/votes/anonymity']",
                text: :prefs_change_image_vote_anonymity.l)
    assert_no_html(html, "a[href='/images/votes/anonymity']" \
                         "[data-turbo-method]")

    # License: plain GET to the bulk-license edit form. The pre-Phlex
    # `put_button` PUT-ed a GET-only route and 404'd — fixed by going
    # through the edit page which owns the actual update form.
    assert_html(html, "a[href='/images/licenses/edit']",
                text: :bulk_license_link.l)
    assert_no_html(html, "a[href='/images/licenses/edit']" \
                         "[data-turbo-method]")

    # Filename purge: the only one without an edit page — direct
    # mutation. Stays a PUT, gated by a turbo-confirm. Pin the full
    # confirm string so a future trim of the i18n entry doesn't
    # silently downgrade the warning the user sees.
    confirm = :prefs_bulk_filename_purge_confirm.l
    assert_html(html, "a[href='/images/purge_filenames']" \
                      "[data-turbo-method='put']" \
                      "[data-turbo-confirm='#{confirm}']",
                text: :prefs_bulk_filename_purge.l)
  end

  # ---- Pre-filled state from @user ----

  def test_login_fields_pre_fill_from_user
    @user.login = "rolfster"
    @user.email = "rolf@example.test"
    html = render_form

    assert_html(html, "input[name='user[login]'][value='rolfster']")
    assert_html(html, "input[name='user[email]'][value='rolf@example.test']")
  end

  def test_privacy_selects_pre_fill_from_user
    @user.votes_anonymous = "yes"
    @user.keep_filenames = "keep_and_show"
    license_id = @user.license.id
    html = render_form

    assert_html(html, "select[name='user[votes_anonymous]'] " \
                      "option[selected][value='yes']")
    assert_html(html, "select[name='user[keep_filenames]'] " \
                      "option[selected][value='keep_and_show']")
    assert_html(html, "select[name='user[license_id]'] " \
                      "option[selected][value='#{license_id}']")
  end

  def test_appearance_state_pre_fills_from_user
    @user.thumbnail_maps = true
    @user.view_owner_id = false
    @user.layout_count = 42
    @user.theme = "Agaricus"
    html = render_form

    # checked attribute matches model boolean state.
    assert_html(html,
                "input[type='checkbox'][name='user[thumbnail_maps]'][checked]")
    assert_no_html(html, "input[type='checkbox']" \
                         "[name='user[view_owner_id]'][checked]")
    assert_html(html, "input[name='user[layout_count]'][value='42']")
    assert_html(html, "select[name='user[theme]'] " \
                      "option[selected][value='Agaricus']")
  end

  def test_notes_template_pre_fills_from_user
    @user.notes_template = "Collector's #"
    html = render_form

    assert_html(html, "textarea[name='user[notes_template]']",
                text: "Collector's #")
  end

  def test_email_checkboxes_pre_fill_from_user
    @user.email_comments_owner = true
    @user.email_names_admin = false
    html = render_form

    assert_html(html, "input[type='checkbox']" \
                      "[name='user[email_comments_owner]'][checked]")
    assert_no_html(html, "input[type='checkbox']" \
                         "[name='user[email_names_admin]'][checked]")
  end

  def test_string_filter_pre_fills_from_content_filter
    filter = Query::Filter.all.find { |f| f.type == [:string] }
    skip("no string filter configured") unless filter

    @user.content_filter[filter.sym] = "California"
    html = render_form

    assert_html(html, "input[name='user[#{filter.sym}]'][value='California']")
  end

  # ---- Filter-type branches ----

  def test_boolean_filter_with_single_prefs_val_renders_checkbox
    filter = Query::Filter.all.find do |f|
      f.type == :boolean && f.prefs_vals.one?
    end
    skip("no single-prefs-val boolean filter") unless filter

    @user.content_filter[filter.sym] = filter.prefs_vals.first
    html = render_form

    assert_html(html,
                "input[type='checkbox'][name='user[#{filter.sym}]'][checked]")
  end

  def test_boolean_filter_with_multi_prefs_vals_renders_select_with_off_option
    filter = Query::Filter.all.find do |f|
      f.type == :boolean && f.prefs_vals.size > 1
    end
    skip("no multi-prefs-val boolean filter") unless filter

    html = render_form

    # Multi-value boolean filters render as a select that includes
    # the filter's "off" value as the first option.
    assert_html(html, "select[name='user[#{filter.sym}]'] " \
                      "option[value='#{filter.off_val}']")
  end

  def test_render_filter_field_raises_on_unknown_type
    # Defensive guard: an unrecognized `filter.type` would silently
    # produce no field. The form raises to surface the bug instead.
    fake = Struct.new(:type, :sym).new(:not_a_real_type, :bogus)
    form = Components::AccountPreferencesForm.new(
      @user, licenses: License.available_names_and_ids(@user&.license)
    )
    assert_raises(RuntimeError) do
      form.send(:render_filter_field, fake)
    end
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
