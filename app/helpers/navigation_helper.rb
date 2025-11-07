module NavigationHelper
    def did_logo_tag(width: 45, style: nil)
        image_tag(t('admin.images.logo_light'), class: "mode-light", style: style, alt: t('admin.images.logo_alt'), width: width) +
        image_tag(t('admin.images.logo_dark'), class: "mode-dark", style: style, alt: t('admin.images.logo_alt'), width: width)
    end

    def sidebar_link(path, key, icon_class)
        active = @current_page == key
        link_to path, class: "nav-link d-flex align-items-center #{active ? 'active' : 'link-body-emphasis'}" do
            concat content_tag(:i, "", class: "#{icon_class} #{'text-body-emphasis' unless active}")
            concat content_tag(:span, t("menu.#{key}"), class: "sidebar-text")
        end
    end

    def offcanvas_link(path, key, icon_class)
        active = @current_page == key
        link_to path, class: "nav-link #{active ? 'active' : 'link-body-emphasis'}", style: "#{active ? nil : 'color: var(--icon-black);'}" do
            concat content_tag(:i, "", class: "#{icon_class} me-2#{' text-body-emphasis' unless active}")
            concat t("menu.#{key}")
        end
    end

    def markdown(text)
        renderer = Redcarpet::Render::HTML.new(filter_html: true, hard_wrap: true)
        markdown = Redcarpet::Markdown.new(renderer, extensions = {fenced_code_blocks: true, autolink: true, tables: true})
        markdown.render(text).html_safe
    end

    def pretty_json(obj)
      return "" if obj.nil?
      json =
        if obj.is_a?(String)
          JSON.parse(obj) rescue obj
        else
          obj
        end
      JSON.pretty_generate(json)
    end

    def sort_link(label, ui_key, allowed:, default_col:, default_dir: "asc", param_prefix: nil, extra_params: {})
      sort_param = [param_prefix, "sort"].compact.join("_")
      dir_param  = [param_prefix, "dir"].compact.join("_")

      # aktuelle Auswahl aus Params
      current_ui_key = params[sort_param]
      current_col    = allowed[current_ui_key] || normalize_default_col(default_col, allowed)
      current_dir    = %w[asc desc].include?(params[dir_param]) ? params[dir_param] : default_dir

      target_col = allowed[ui_key] or raise ArgumentError, "Unknown ui_key: #{ui_key}"
      next_dir   = (current_col == target_col && current_dir == "asc") ? "desc" : "asc"

      # Icon nur zeigen, wenn Spalte aktiv
      arrow_html =
        if current_col == target_col
          icon = current_dir == "asc" ? "bi-caret-up-fill" : "bi-caret-down-fill"
          %Q(<i class="bi #{icon} ms-1" aria-hidden="true"></i>)
        else
          ""
        end

      merged = request.query_parameters.symbolize_keys
                    .merge(extra_params.symbolize_keys)
                    .merge(sort_param.to_sym => ui_key, dir_param.to_sym => next_dir, page: nil)

      link = url_for(merged)
      %Q(<a href="#{ERB::Util.h(link)}" class="text-decoration-none">#{ERB::Util.h(label)}#{arrow_html}</a>).html_safe
    end

    def set_sorting_support
      adapter = ActiveRecord::Base.connection.adapter_name.downcase

      @json_text =
        if adapter.include?("postgres")
          # verschachtelte Keys: ->(col, *keys)
          ->(col, *keys) do
            # baue (col::jsonb -> 'k1' -> 'k2' ->> 'last')
            head, *rest = keys
            chain = rest[0..-2].reduce("(#{col}::jsonb -> '#{head}')") { |acc, k| "#{acc} -> '#{k}'" }
            last = rest.empty? ? head : rest.last
            rest.empty? ? "(#{col}::jsonb ->> '#{head}')" : "#{chain} ->> '#{last}'"
          end
        else
          # SQLite json1: $.item.use_case
          ->(col, *keys) { "json_extract(#{col}, '$.#{keys.join('.') }')" }
        end

      @order_sql =
        if adapter.include?("postgres")
          ->(expr, dir) { "#{expr} #{dir.upcase} NULLS LAST" }
        else
          ->(expr, dir) { "CASE WHEN #{expr} IS NULL THEN 1 ELSE 0 END, #{expr} #{dir.upcase}" }
        end
    end
    
    private

    # erlaubt default_col als UI-Key *oder* DB-Spaltenname
    def normalize_default_col(default_col, allowed)
      return allowed[default_col] if allowed.key?(default_col) # war UI-Key
      return default_col if allowed.values.include?(default_col) # war DB-Spalte
      allowed.values.first # Fallback
    end
    
end