# frozen_string_literal: true

# Action template for `FieldSlipsController#index` — the paginated
# list of field-slips. Two head sections gate on whether the query is
# scoped to a single project: when `@project` is set, shows the
# project's field-slip prefix (or a nudge for admins when none is
# set); otherwise renders an inline filter form scoped to project.
# Body is a `Components::ListGroup` of `FieldSlipPanel`-rendered
# entries, one per `@object`, each with a per-row code-link heading
# fed in via the panel's `:prepend` slot.
module Views::Controllers::FieldSlips
  class Index < Views::FullPageBase
    prop :objects, _Array(::FieldSlip)
    prop :query, ::Query::FieldSlips
    prop :project, _Nilable(::Project), default: nil
    prop :pagination_data, ::PaginationData
    prop :notice, _Nilable(String), default: nil

    def view_template
      add_project_banner(@project) if @project
      add_index_title(@query)
      add_context_nav(Tab::FieldSlip::IndexActions.new)
      add_pagination(@pagination_data)
      container_class(:wide)

      render_notice
      ContentPadded { render_project_or_filter_section }
      render_list
    end

    private

    def render_notice
      return unless @notice

      Alert(message: @notice, level: :success)
    end

    def render_project_or_filter_section
      if @project
        render_project_info_section
      else
        render_filter_form
      end
    end

    def render_project_info_section
      if @project.field_slip_prefix
        render_existing_prefix_block
      elsif @project.is_admin?(current_user)
        render_no_prefix_nudge
      end
    end

    def render_existing_prefix_block
      div(class: "mt-3") do
        b { plain("#{:show_project_field_slip_prefix.t}:") }
        plain(" #{@project.field_slip_prefix} ")
        if @project.member?(current_user)
          Button(
            type: :get,
            name: :show_project_field_slip_create.t,
            target: new_project_field_slip_path(
              project_id: @project.id
            )
          )
        end
      end
    end

    def render_no_prefix_nudge
      div(class: "alert alert-info mt-3",
          id: "field_slip_no_prefix_nudge") do
        plain(:show_project_field_slip_no_prefix.t)
        whitespace
        link_to(:show_project_field_slip_set_prefix.t,
                project_admin_path(project_id: @project.id),
                class: "alert-link")
      end
    end

    def render_filter_form
      project_field = Components::ApplicationForm::FieldProxy.new(
        nil, :project_name, project_title
      )
      IndexFilter(
        to: field_slips_path, submit_text: "Filter"
      ) do
        render(Components::ApplicationForm::AutocompleterField.new(
                 project_field,
                 type: :project, hidden_name: :project, inline: true,
                 size: 60, class: "mb-0",
                 label: "#{:field_slip_filter_by.l}:"
               ))
      end
    end

    def render_list
      PaginatedResults do
        ListGroup do |list|
          @objects.each do |fs|
            list.item do
              render(FieldSlipPanel.new(
                       field_slip: fs, prepend: row_prepend(fs)
                     ))
            end
          end
        end
      end
    end

    # The `<h4>` heading the index page tucks in front of every row's
    # field-slip panel — code with a link back to the slip.
    def row_prepend(field_slip)
      capture do
        h4 do
          strong { plain("#{:field_slip_code.l}: ") }
          link_to(field_slip.code, field_slip,
                  class: "field_slip_link_#{field_slip.id}")
          br
        end
      end
    end

    def project_title
      @project_title ||= cached_project_filter&.title.to_s
    end

    def cached_project_filter
      @query&.params_cache&.dig(:project)
    end
  end
end
