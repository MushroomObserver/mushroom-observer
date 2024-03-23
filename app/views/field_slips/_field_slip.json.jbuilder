# frozen_string_literal: true

json.extract!(field_slip, :id, :observation_id, :project_id, :code,
              :created_at, :updated_at)
json.url(field_slip_url(field_slip, format: :json))
