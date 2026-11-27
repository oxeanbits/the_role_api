require 'rails-i18n'
require 'stringex_lite'

# Role section and rule names are stored as slugs, so this must produce exactly what
# to_slug_param 1.8 produced. That gem is unmaintained and its gemspec caps Rails below 7,
# so its slug algorithm lives here now.
module TheRoleApi
  module SlugParam
    DEFAULT_SEPARATOR = '-'.freeze
    DEFAULT_TOLERANCE = 75
    SPECIAL_SYMBOLS = %[`'"<>[]{}()-+?!/\\.:;|#\$@&*^%=~_].freeze
    SPECIAL_SYMBOLS_REGEXP = Regexp.union(SPECIAL_SYMBOLS.chars)

    class << self
      # Picks the transliterated slug unless it lost too much of the string compared
      # to the stringex one (e.g. scripts that I18n cannot transliterate).
      def slugify(value, opts = {})
        opts = opts.symbolize_keys
        tolerance = opts[:tolerance] || DEFAULT_TOLERANCE
        str = parameterize(value, separator(opts))

        transliterated = transliterated_slug(str, opts)
        stringex_slug = parameterize(str.to_url, separator(opts))

        pick_slug(transliterated, stringex_slug, tolerance)
      end

      private

      def transliterated_slug(str, opts)
        sep = separator(opts)
        str = I18n.transliterate(parameterize(str, sep), **opts)
        str = remove_separator_duplications(str, sep)

        ActiveSupport::Inflector.parameterize(str, separator: sep)
      end

      def pick_slug(transliterated, stringex_slug, tolerance)
        ratio = transliterated.size.to_f / stringex_slug.size

        return '' if ratio.nan?
        return transliterated if ratio.infinite?
        return stringex_slug if ratio.zero?

        (ratio * 100).to_i > tolerance ? transliterated : stringex_slug
      end

      def parameterize(value, sep)
        str = value.to_s.strip.gsub(/[[:space:]]/, sep)
        str = str.gsub(SPECIAL_SYMBOLS_REGEXP, sep)
        remove_separator_duplications(str, sep)
      end

      def remove_separator_duplications(str, sep)
        escaped_sep = Regexp.escape(sep)

        str.gsub(/\A#{escaped_sep}+/, '')
           .gsub(/#{escaped_sep}{2,}/, sep)
           .gsub(/#{escaped_sep}+\z/, '').to_s
      end

      def separator(opts)
        opts[:sep] || DEFAULT_SEPARATOR
      end
    end
  end
end

class String
  def to_slug_param(opts = {})
    TheRoleApi::SlugParam.slugify(self, opts)
  end
end

class Symbol
  def to_slug_param(opts = {})
    TheRoleApi::SlugParam.slugify(to_s, opts)
  end
end
