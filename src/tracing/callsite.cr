module Tracing
  module Core
    module Callsite
      # Indicates the subscriber's interest in a callsite.
      enum Interest
        NEVER
        SOMETIMES
        ALWAYS

        def self.never : self
          NEVER
        end

        def self.sometimes : self
          SOMETIMES
        end

        def self.always : self
          ALWAYS
        end
      end

      # Trait implemented by callsites.
      module Interface
        abstract def interest=(interest : Interest) : Nil
        abstract def metadata : Metadata
      end

      # A default ready-made callsite implementation.
      class DefaultCallsite
        include Interface

        getter metadata : Metadata

        def initialize(@metadata : Metadata = Metadata.new("", "", Level::INFO))
          @interest = Interest.sometimes
        end

        def interest : Interest
          @interest
        end

        def interest=(@interest : Interest) : Nil
        end
      end
    end
  end
end
