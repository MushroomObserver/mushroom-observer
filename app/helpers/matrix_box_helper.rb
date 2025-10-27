# frozen_string_literal: true

# This module previously contained helpers for matrix_table and matrix_box,
# but those have been replaced by Phlex components:
# - MatrixTable component (for grids of matrix boxes)
# - MatrixBox component (for rendering objects or custom block content)
#
# Templates now render these components directly using:
#   <%= render MatrixTable.new(objects: @objects) %>
#   <%= render MatrixBox.new(user: @user, object: @observation) %>
#   <%= render MatrixBox.new(id: 123) { custom_content } %>
module MatrixBoxHelper
end
