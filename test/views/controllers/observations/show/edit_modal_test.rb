# frozen_string_literal: true

require("test_helper")

class Views::Controllers::Observations::Show::EditModalTest <
  ComponentTestCase
  def setup
    super
    @user = users(:rolf)
  end

  # Editable non-primary: Edit Primary + Edit This + Cancel, no
  # reflection explanation.
  def test_editable_non_primary_buttons
    primary = make_editable(:coprinus_comatus_obs)
    other = make_editable(:detailed_unknown_obs)
    occ = occurrence_for(primary, [primary, other])

    html = render_modal(other, occ)

    assert_includes(html, :edit_occurrence_modal_title.l)
    assert_includes(html, :edit_occurrence_not_primary.l)
    assert_html(html, "a[href='#{edit_path(other, target: :primary)}']",
                text: :edit_occurrence_edit_primary.l)
    assert_html(html, "a[href='#{edit_path(other)}']",
                text: :edit_occurrence_edit_this.l)
    assert_html(html, "button[data-dismiss='modal']")
    assert_not_includes(html, :edit_occurrence_is_reflection.l)
  end

  # Reflection with an editable sibling: Edit Primary + Cancel, no Edit
  # This, plus the reflection explanation.
  def test_reflection_with_editable_sibling_buttons
    reflection = make_editable(:detailed_unknown_obs)
    reflection.update_column(:reflected_at, Time.zone.now)
    native = make_editable(:coprinus_comatus_obs)
    occ = occurrence_for(native, [reflection, native])

    html = render_modal(reflection, occ)

    assert_includes(html, :edit_occurrence_edit_match_title.l)
    assert_html(html, "a[href='#{edit_path(reflection, target: :primary)}']",
                text: :edit_occurrence_edit_primary.l)
    assert_no_html(html, "a[href='#{edit_path(reflection)}']")
    assert_includes(html, :edit_occurrence_is_reflection.l)
  end

  # Reflection with no editable sibling: Create Editable Primary. It is
  # its occurrence's current primary, so the "not primary" line is
  # omitted; only the read-only-reflection line shows.
  def test_lone_reflection_offers_create
    reflection = make_editable(:coprinus_comatus_obs)
    reflection.update_column(:reflected_at, Time.zone.now)
    occ = occurrence_for(reflection, [reflection])

    html = render_modal(reflection, occ)

    assert_includes(html, :edit_occurrence_create_title.l)
    assert_html(html, "a[href='#{edit_path(reflection, target: :primary)}']",
                text: :edit_occurrence_create_primary.l)
    assert_no_html(html, "a[href='#{edit_path(reflection)}']")
    assert_includes(html, :edit_occurrence_is_reflection.l)
    assert_not_includes(html, :edit_occurrence_not_primary.l)
  end

  # A reflection with no occurrence yet still offers Create Editable
  # Primary; only the read-only line shows (no "not primary").
  def test_reflection_without_occurrence_offers_create
    reflection = make_editable(:coprinus_comatus_obs)
    reflection.update_column(:reflected_at, Time.zone.now)

    html = render_modal(reflection, nil)

    assert_html(html, "a[href='#{edit_path(reflection, target: :primary)}']",
                text: :edit_occurrence_create_primary.l)
    assert_includes(html, :edit_occurrence_is_reflection.l)
    assert_not_includes(html, :edit_occurrence_not_primary.l)
  end

  # Admin mode grants edit rights, so a sibling the user can't edit
  # still counts as an editable sibling -- the label is Edit Primary,
  # not Create Editable Primary.
  def test_admin_mode_counts_non_editable_sibling
    reflection = make_editable(:coprinus_comatus_obs)
    reflection.update_column(:reflected_at, Time.zone.now)
    native = observations(:detailed_unknown_obs)
    native.update_columns(user_id: users(:mary).id, collector_user_id: nil,
                          occurrence_id: nil)
    assert_not(native.can_edit?(@user), "premise: native not editable by user")
    occ = occurrence_for(reflection, [reflection, native])

    without_admin = render_modal(reflection, occ)
    assert_html(without_admin,
                "a[href='#{edit_path(reflection, target: :primary)}']",
                text: :edit_occurrence_create_primary.l)

    stub_admin_mode!
    with_admin = render_modal(reflection, occ)
    assert_html(with_admin,
                "a[href='#{edit_path(reflection, target: :primary)}']",
                text: :edit_occurrence_edit_primary.l)
  end

  private

  def edit_path(obs, **)
    Rails.application.routes.url_helpers.edit_observation_path(obs.id, **)
  end

  def make_editable(fixture)
    obs = observations(fixture)
    obs.update_columns(user_id: @user.id, collector_user_id: @user.id,
                       occurrence_id: nil)
    obs
  end

  def occurrence_for(primary, members)
    occ = Occurrence.create!(user: @user, primary_observation: primary)
    members.each { |m| m.update_column(:occurrence_id, occ.id) }
    occ
  end

  def render_modal(obs, occ)
    render(Views::Controllers::Observations::Show::EditModal.new(
             observation: obs, occurrence: occ, user: @user
           ))
  end
end
