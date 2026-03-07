# frozen_string_literal: true

json.id(field_slip.id)
json.observation_id(field_slip.observation&.id)
json.project_id(field_slip.project_id)
json.code(field_slip.code)
json.created_at(field_slip.created_at)
json.updated_at(field_slip.updated_at)
json.url(field_slip_url(field_slip, format: :json))
