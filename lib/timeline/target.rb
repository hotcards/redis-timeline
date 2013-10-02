module Timeline
  module Target
    extend ActiveSupport::Concern

    included do
      def activities(options={})
        ::Timeline.get_list(timeline_options_for_target(options)).map do |item|
          ::Timeline::Activity.new ::Timeline.decode(item)
        end
      end

      private
        def timeline_options_for_target(options)
          defaults = { list_name: "target:id:#{self.id}:activity", start: 0, end: 19 }
          defaults.merge!(options) if options.is_a? Hash
        end
    end
  end
end