# frozen_string_literal: true

module Newsletter
  # Minimal, non-personal acquisition attribution. Unknown sources and invalid
  # campaign slugs are silently dropped.
  module Attribution
    SOURCES = { "blog" => "blog", "site" => "site", "facebook" => "facebook", "fb" => "facebook",
                "instagram" => "instagram", "ig" => "instagram" }.freeze
    CAMPAIGN = /\A[a-z0-9-]{1,40}\z/

    module_function

    def source(value)
      SOURCES[value.to_s.strip.downcase]
    end

    def campaign(value)
      v = value.to_s.strip.downcase
      v.match?(CAMPAIGN) ? v : nil
    end
  end
end
