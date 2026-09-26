# frozen_string_literal: true

# Unlicensed-observations count on the iNat Import Confirm page.
# Rendered by ConfirmForm in one of three modes:
#   :self_import - user imports own obss; informational line
#                  (imported regardless of license)
#   :skeleton    - import-others with skeletons; informational line
#                  (imported as placeholders)
#   :ignored     - import-others without skeletons; a row inside the Total
#                  Ignored Observations breakdown
# The count renders even when blank/zero, so a failed estimate is visible
# as blank, distinguishable from a zero.
class Views::Controllers::InatImports::ConfirmForm::UnlicensedLine <
  Components::Base
  prop :count, _Nilable(::Integer)
  prop :url, _Nilable(::String)
  prop :mode, _Union(:self_import, :skeleton, :ignored)

  def view_template
    case @mode
    when :ignored then div(class: "mb-1") { render_ignored_row }
    when :skeleton then render_line(:inat_import_confirm_skeleton_obs_caption)
    else
      render_line(:inat_import_confirm_unlicensed_obs_caption)
      render_note(:inat_import_confirm_unlicensed_obs_note)
    end
  end

  private

  def render_ignored_row
    b { append_colon(:inat_import_confirm_unlicensed_obs_caption.l) }
    render_count
    render_note(:inat_import_confirm_unlicensed_others_note)
  end

  def render_line(caption_key)
    b { plain(caption_key.l) }
    plain(": ")
    render_count
  end

  def render_count
    span(id: "unlicensed_obs_count") do
      if @url
        render(Components::Link::External.new(content: @count.to_s,
                                              path: @url))
      else
        plain(@count.to_s)
      end
    end
  end

  def render_note(note_key)
    return unless @count.to_i.positive?

    whitespace
    plain(note_key.l)
  end
end
