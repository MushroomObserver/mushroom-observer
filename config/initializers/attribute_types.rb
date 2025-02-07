# frozen_string_literal: true

require("array_type")

ActiveModel::Type.register(:array, ArrayType)
