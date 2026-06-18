# frozen_string_literal: true

# Stub form-object for `Components::ListGroup::Search`. Has no attributes —
# the list-search form posts flat top-level params (`name`,
# `field_slip`, `object_id`, `object_type`, `project`) to
# `AddDispatchController`, and the Phlex view uses String-keyed
# field helpers so the param namespacing the form-object would
# normally provide is not used. The class exists only because
# `Superform::Rails::Form` requires a model that responds to
# `model_name` — `FormObject::Base.model_name` returns one derived
# from the demodulized class name (here, "ListSearch").
class FormObject::ListSearch < FormObject::Base
end
