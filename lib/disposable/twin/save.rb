class Disposable::Twin
  module Save
    class Command

      def save(model)
        model.save
      end
    end
    attr_reader :command

    def initialize(model, options={})
      @command = options[:command] || Command.new
      super
    end

    # Returns the result of that save invocation on the model.
    def save(options={}, &block)
      res = sync(&block)
      return res if block_given?

      save!(options)
    end

    def save!(options={})
      result = save_model

      schema.each(twin: true) do |dfn|
        next if dfn[:save] == false

        # call #save! on all nested twins.
        PropertyProcessor.new(dfn, self).() { |twin| twin.save! }
      end

      result
    end

    def save_model
      command.save(model)
    end
  end
end
