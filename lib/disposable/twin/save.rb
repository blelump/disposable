class Disposable::Twin
  module Save
    class DefaultCommand

      def save(model)
        model.save
      end

      def persisted?(model)
        model.persisted?
      end
    end
    attr_reader :save_opts

    def initialize(model, options={})
      @save_opts = default_save_opts.merge(options)
      super
    end

    def default_save_opts
      {command: DefaultCommand.new}
    end

    # Returns the result of that save invocation on the model.
    def save(options={}, &block)
      res = sync(&block)
      return res if block_given?

      save!(options.merge(save_opts))
    end

    def save!(options={})
      result = save_model(options)

      schema.each(twin: true) do |dfn|
        next if dfn[:save] == false

        # call #save! on all nested twins.
        PropertyProcessor.new(dfn, self).() do |twin|
          twin.save!(options)
        end
      end

      result
    end

    def save_model(options = {})
      options[:command].save(model)
    end
  end
end
