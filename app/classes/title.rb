# frozen_string_literal: true

# Computes the page heading (`page_title`) and browser-tab title
# (`document_title`) for an arbitrary AbstractModel instance. Moved off
# the models themselves (#4901) -- was a polymorphic method contract
# with 14 per-model overrides directly on the AR classes, several
# resolving translation tags. Consumed only from Phlex views
# (app/views/layouts/header/object_title.rb,
# app/views/full_page_base/title.rb), so this lives at the view-facing
# edge rather than on the model, same shape as ViewerAwareFormat and
# the Tab:: PORO family.
#
# One subclass per model that needs bespoke logic, discovered by
# naming convention -- same mechanism as ApplicationMailer's
# `mailer_view_class` (`"Views::Mailers::#{class_name}".constantize`).
# Models with no Title:: subclass fall through to this base class's
# defaults, matching AbstractModel#type_tag's localized label -- the
# same default the models themselves used to inherit.
class Title
  # Walks up the class hierarchy (not just object.class itself) so
  # NameDescription/LocationDescription -- concrete subclasses of the
  # abstract Description, which is where the title logic actually
  # lives -- resolve to Title::Description instead of silently
  # falling through to the generic default.
  def self.for(object)
    klass = object.class
    while klass
      title_class = "Title::#{klass.name}".safe_constantize
      return title_class.new(object) if title_class
      break if klass == AbstractModel

      klass = klass.superclass
    end
    new(object)
  end

  def initialize(object)
    @object = object
  end

  def page_title(_user = nil)
    @object.type_tag.ti
  end

  def document_title
    @object.type_tag.ti
  end
end
