# frozen_string_literal: true

# "See more" link to the name's primary description. Caller must
# guard on `name&.description` before constructing.
class Tab::Name::ShowDescription < Tab::Base
  def initialize(name:)
    super()
    @name = name
  end

  def title
    :show_name_see_more.l
  end

  def path
    name_description_path(@name.description.id)
  end

  def html_options
    { icon: :list }
  end

  def model
    @name
  end
end
