# frozen_string_literal: true

# Page heading uses the textilized herbarium_label (binomial inside
# gets italicized). Doc title uses the plain accession string.
class Title::HerbariumRecord < Title
  def page_title(_user = nil)
    @object.herbarium_label.t
  end

  def document_title
    @object.herbarium_label
  end
end
