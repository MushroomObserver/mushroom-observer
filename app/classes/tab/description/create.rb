# frozen_string_literal: true

# "Create a description for this name/location" link. The `parent`
# is the Name or Location object; the type is derived from
# `parent.type_tag` (:name or :location).
class Tab::Description::Create < Tab::Base
  def initialize(parent:)
    super()
    @parent = parent
    @type = parent.type_tag
  end

  def title
    :show_name_create_description.t
  end

  def path
    send(:"new_#{@type}_description_path",
         { "#{@type}_id": @parent.id })
  end

  def html_options
    { icon: :add }
  end

  def model
    @type == :name ? NameDescription : LocationDescription
  end
end
