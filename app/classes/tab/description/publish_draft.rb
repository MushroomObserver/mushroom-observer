# frozen_string_literal: true

# "Publish this draft (make it public)" PUT-button tab. NameDescription
# only (LocationDescriptions aren't drafted). Caller is responsible
# for the admin + non-public-source checks before instantiating.
class Tab::Description::PublishDraft < Tab::Base
  def initialize(description:)
    super()
    @description = description
  end

  def title
    :show_description_publish.t
  end

  def path
    publish_name_description_path(@description.id)
  end

  def html_options
    { button: :put, help: :show_description_publish_help.l, icon: :publish }
  end

  def model
    @description
  end
end
