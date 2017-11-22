module SSDB
  module Type
    class JSON
      SUPPORT_TYPES = [
        ::Array,
        ::Hash
      ]

      def initialize(val)
        @val = self.class.valid_type(val) ? val : nil
      end

      def encode
        return if @val.nil?
        ActiveSupport::JSON.encode(@val)
      end

      def self.decode(val)
        return val if valid_type(val)
        if val.is_a?(String) && val.present?
          data = ActiveSupport::JSON.decode(val)
          res = valid_type(data) && data || nil
        end
        if res.nil? && !val.nil?
          ActiveSupport::Deprecation.warn("json ssdb-attr only supported to serialize array or hash data")
        end
        res
      end

      private
      def self.valid_type(val)
        SUPPORT_TYPES.any? { |type| val.is_a?(type) }
      end
    end
  end
end
