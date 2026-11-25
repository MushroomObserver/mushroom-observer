# frozen_string_literal: true

require("test_helper")

# rubocop:disable MO/NoCosmeticClassAssertion -- Title's whole job is
# deciding whether to add font-weight-bold; the class IS the contract.
class MatrixBoxTitleTest < ComponentTestCase
  def test_observation_type_is_not_bold_by_default
    html = render_title(type: :observation)

    assert_no_html(html, ".font-weight-bold")
  end

  def test_other_types_are_bold_by_default
    html = render_title(type: :user)

    assert_html(html, ".font-weight-bold")
  end

  def test_bold_true_overrides_observation_default
    html = render_title(type: :observation, bold: true)

    assert_html(html, ".font-weight-bold")
  end

  def test_bold_false_overrides_non_observation_default
    html = render_title(type: :image, bold: false)

    assert_no_html(html, ".font-weight-bold")
  end

  private

  def render_title(type:, bold: nil)
    render(Components::Matrix::Box::Title.new(
             id: 1, name: "Some Title", type: type, bold: bold
           ))
  end
end
# rubocop:enable MO/NoCosmeticClassAssertion
