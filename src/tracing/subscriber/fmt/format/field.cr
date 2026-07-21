module Tracing
  module FmtField
    module MakeVisitor(T)
      abstract def make_visitor(target : T) : Core::Field::Visit
    end

    module VisitOutput
      abstract def finish : Nil
    end

    module VisitFmt
      include VisitOutput

      abstract def writer : IO
    end

    module RecordFields
      abstract def record(visitor : Core::Field::Visit)
    end
  end
end

class Tracing::Core::Field::ValueSet
  include Tracing::FmtField::RecordFields

  def record(visitor : Tracing::Core::Field::Visit) : Nil
    visit(visitor)
  end
end
