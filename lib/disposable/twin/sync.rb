# #sync!
#   1. assign scalars to model (respecting virtual, excluded attributes)
#   2. call sync! on nested
#
# Note: #sync currently implicitly saves AR objects with collections
module Disposable::Twin::Sync
  def sync_models(options={})
    sync!(options)
  end
  alias_method :sync, :sync_models

  # reading from fields allows using readers in form for presentation
  # and writers still pass to fields in #validate????
  def sync!(options) # semi-public.
    # options = Disposable::Representer::Options[options.merge(:form => self)] # options local for this form, only.

    sync_representer.new(model).from_object(self, options) # sync properties to Song.
    # dynamic_sync_representer.new(aliased_model).from_hash(input, options) # sync properties to Song.
    # dynamic_sync_representer.new(model).from_hash(input, options) # sync properties to Song.
  end

private
  # Writes twin to model.
  def sync_representer
    self.class.representer(:sync, :all => true, :superclass => self.class.object_representer_class) do |dfn|
      dfn.merge!(
        :instance     => lambda { |fragment, *| fragment }, # use model's nested property for syncing.
          # FIXME: do we allow options for #sync for nested forms?
        :deserialize => lambda { |object, *| model = object.sync!({}) } # sync! returns the synced model.
        # representable's :setter will do collection=([..]) or property=(..) for us on the model.
      ) if dfn[:twin]
    end
  end

   # TODO: integrate features below!!!!!!

  # This representer inherits from sync_representer and add functionality on top of that.
  # It allows running custom dynamic blocks for properties when syncing.
  def dynamic_sync_representer
    self.class.representer(:dynamic_sync, superclass: sync_representer, :all => true) do |dfn|
      next unless setter = dfn[:sync]

      setter_proc = lambda do |value, options|
        if options.binding[:sync] == true # sync: true will call the runtime lambda from the options hash.
          options.user_options[options.binding.name.to_sym].call(value, options)
          next
        end

        # evaluate the :sync block in form context (should we do that everywhere?).
        options.user_options[:form].instance_exec(value, options, &setter)
      end

      dfn.merge!(:setter => setter_proc)
    end
  end


  # API: semi-public.
  module SyncHash
    # This hash goes into the Writer that writes properties back to the model. It only contains "writeable" attributes.
    def sync_hash(options)
      input_representer.new(self).to_hash(options)
    end
  end
  include SyncHash


  # Excludes :virtual and readonly properties from #sync in this form.
  module Writeable
    def sync_hash(options)
      # FIXME:
      readonly_fields = []# mapper.fields { |dfn| dfn[:_writeable] == false }

      # options.exclude!(readonly_fields.map(&:to_sym))

      super
    end
  end
  include Writeable


  # This will skip unchanged properties in #sync. To use this for all nested form do as follows.
  #
  #   class SongForm < Reform::Form
  #     feature Synd::SkipUnchanged
  module SkipUnchanged
    def sync_hash(options)
      # DISCUSS: we currently don't track if nested forms have changed (only their attributes). that's why i include them all here, which
      # is additional sync work/slightly wrong. solution: allow forms to form.changed? not sure how to do that with collections.
      scalars   = mapper.fields { |dfn| !dfn[:form] }
      unchanged = scalars - changed.keys

      # exclude unchanged scalars, nested forms and changed scalars still go in here!
      options.exclude!(unchanged.map(&:to_sym))
      super
    end
  end
end