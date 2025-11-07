module Sortable
  extend ActiveSupport::Concern

  def sort_order(allowed:, default_key: nil, default_col: nil, default_dir: "asc", param_prefix: nil)
    sort_param = [param_prefix, "sort"].compact.join("_")
    dir_param  = [param_prefix, "dir"].compact.join("_")

    ui_key = params[sort_param]
    cfg    = allowed[ui_key] || (default_key && allowed[default_key]) || nil

    expr, dir_from_cfg =
      case cfg
      when String
        [cfg, nil]
      when Hash
        raw = cfg[:expr]
        resolved = raw.respond_to?(:call) ? instance_exec(&raw) : raw
        [resolved, cfg[:default_dir]]
      else
        [nil, nil]
      end

    # Fallback, wenn keine gültige Konfiguration ermittelt wurde
    expr ||= begin
      if default_key && allowed[default_key]
        val = allowed[default_key]
        val.is_a?(Hash) ? (val[:expr].respond_to?(:call) ? instance_exec(&val[:expr]) : val[:expr]) : val
      else
        default_col
      end
    end

    # Richtung aus Params, sonst spalteneigener Default, sonst globaler Default
    chosen_dir = params[dir_param]
    dir = %w[asc desc].include?(chosen_dir) ? chosen_dir : (dir_from_cfg || default_dir)
    Arel.sql("#{expr} #{dir.upcase}")
  end
end