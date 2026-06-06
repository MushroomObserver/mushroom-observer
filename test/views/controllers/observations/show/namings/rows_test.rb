# frozen_string_literal: true

require("test_helper")

class Views::Controllers::Observations::Show::Namings::RowsTest <
  ComponentTestCase
  def setup
    super
    @obs = observations(:coprinus_comatus_obs)
    @user = @obs.user
    @consensus = ::Observation::NamingConsensus.new(@obs)
    controller.instance_variable_set(:@user, @user)
  end

  def test_container_carries_turbo_target_id_and_flush
    # The container id is the Turbo Stream target that
    # `NamingsController#create` / `destroy` (and the votes
    # controller) write into. `list-group-flush` borrows the
    # parent panel's border instead of drawing its own.
    html = render_rows

    assert_html(html, "div#namings_table_rows.list-group.list-group-flush")
  end

  def test_renders_one_list_group_item_per_merged_naming
    # `merged_namings` collapses occurrence-sibling rows; pin
    # one-item-per-result so a future change to the consensus
    # surface fails this rather than going unnoticed.
    html = render_rows
    expected = @consensus.merged_namings.count

    assert_html(html, "div.list-group-item:not(.none-yet)",
                count: expected)
  end

  def test_items_carry_observation_naming_row_inside
    # Each item wraps the inner Row which carries the
    # `observation_naming_<id>` selector on its `.naming-row` div.
    html = render_rows
    first_naming = @consensus.merged_namings.first

    assert_html(html, "div.list-group-item " \
                      "div#observation_naming_#{first_naming.id}")
  end

  def test_none_yet_placeholder_emitted_alongside_rows
    # ListGroup always emits the empty-state placeholder as a
    # trailing `.none-yet` item; `_utilities.scss` hides it
    # unless it's the `:only-child`. With real rows present, it
    # ships but stays hidden.
    html = render_rows

    assert_html(html, "div.list-group-item.none-yet")
    assert_includes(html, :show_namings_no_names_yet.t)
  end

  def test_only_placeholder_when_no_namings
    # Stub an empty merged_namings so the placeholder is the only
    # child — CSS shows it because of the `:only-child` rule.
    @consensus.stub(:merged_namings, []) do
      html = render_rows

      assert_html(html, "div.list-group-item",
                  count: 1)
      assert_html(html, "div.list-group-item.none-yet")
    end
  end

  private

  def render_rows(user: @user, consensus: @consensus)
    render(Views::Controllers::Observations::Show::Namings::Rows.new(
             user: user, consensus: consensus
           ))
  end
end
