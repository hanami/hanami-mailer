# frozen_string_literal: true

RSpec.describe Hanami::Mailer::DSL::PluckyProc do
  describe ".from_name" do
    it "returns PluckyProc when given a proc" do
      proc = -> { "result" }
      context = Object.new

      plucky_proc = described_class.from_name(proc, :unused_name, context)

      expect(plucky_proc).to be_a(described_class)
      expect(plucky_proc.proc).to eq(proc)
    end

    it "returns PluckyProc when context responds to method name" do
      context = Class.new do
        def my_method
          "from method"
        end
      end.new

      plucky_proc = described_class.from_name(nil, :my_method, context)

      expect(plucky_proc).to be_a(described_class)
      expect(plucky_proc.proc).to be_a(Method)
    end

    it "finds private methods on context" do
      context = Class.new do
        private

        def private_method
          "private result"
        end
      end.new

      plucky_proc = described_class.from_name(nil, :private_method, context)

      expect(plucky_proc).to be_a(described_class)
    end

    it "returns nil when no proc and context doesn't respond to name" do
      context = Object.new

      plucky_proc = described_class.from_name(nil, :nonexistent, context)

      expect(plucky_proc).to be_nil
    end

    it "prefers proc over method lookup" do
      proc = -> { "from proc" }
      context = Class.new do
        def my_method
          "from method"
        end
      end.new

      plucky_proc = described_class.from_name(proc, :my_method, context)

      expect(plucky_proc.call({})).to eq("from proc")
    end
  end

  describe "#call" do
    describe "with no parameters" do
      it "calls proc with no arguments" do
        proc = -> { "simple result" }
        context = Object.new
        plucky_proc = described_class.new(proc, context: context)

        result = plucky_proc.call({})

        expect(result).to eq("simple result")
      end

      it "returns nil when proc is nil" do
        plucky_proc = described_class.new(nil, context: Object.new)

        result = plucky_proc.call({foo: "bar"})

        expect(result).to be_nil
      end
    end

    describe "with keyword parameters" do
      it "extracts required keyword arguments from input" do
        proc = ->(name:) { "Hello, #{name}!" }
        context = Object.new
        plucky_proc = described_class.new(proc, context: context)

        result = plucky_proc.call({name: "Alice", extra: "ignored"})

        expect(result).to eq("Hello, Alice!")
      end

      it "extracts optional keyword arguments from input" do
        proc = ->(greeting: "Hi") { "#{greeting}, world!" }
        context = Object.new
        plucky_proc = described_class.new(proc, context: context)

        result = plucky_proc.call({greeting: "Hello"})

        expect(result).to eq("Hello, world!")
      end

      it "uses default when optional keyword not in input" do
        proc = ->(greeting: "Hi") { "#{greeting}, world!" }
        context = Object.new
        plucky_proc = described_class.new(proc, context: context)

        result = plucky_proc.call({})

        expect(result).to eq("Hi, world!")
      end

      it "extracts multiple keyword arguments" do
        proc = ->(first:, last:, title: "Mr.") { "#{title} #{first} #{last}" }
        context = Object.new
        plucky_proc = described_class.new(proc, context: context)

        result = plucky_proc.call({first: "John", last: "Doe", title: "Dr."})

        expect(result).to eq("Dr. John Doe")
      end
    end

    describe "with keyrest (**kwargs)" do
      it "passes all input as kwargs" do
        proc = ->(**kwargs) { kwargs }
        context = Object.new
        plucky_proc = described_class.new(proc, context: context)

        result = plucky_proc.call({a: 1, b: 2, c: 3})

        expect(result).to eq({a: 1, b: 2, c: 3})
      end

      it "extracts named keywords while passing rest to keyrest" do
        proc = ->(name:, **rest) { {name: name, rest: rest} }
        context = Object.new
        plucky_proc = described_class.new(proc, context: context)

        result = plucky_proc.call({name: "Alice", age: 30, city: "NYC"})

        # Named keyword is extracted; keyrest gets remaining keys from merged input
        expect(result[:name]).to eq("Alice")
        expect(result[:rest]).to include(age: 30, city: "NYC")
      end
    end

    describe "with positional parameters (dependencies)" do
      it "passes positional arguments through" do
        proc = ->(dep1, dep2) { "#{dep1} and #{dep2}" }
        context = Object.new
        plucky_proc = described_class.new(proc, context: context)

        result = plucky_proc.call({}, "first", "second")

        expect(result).to eq("first and second")
      end

      it "combines positional args with keyword extraction" do
        proc = ->(multiplier, value:) { multiplier * value }
        context = Object.new
        plucky_proc = described_class.new(proc, context: context)

        result = plucky_proc.call({value: 10}, 3)

        expect(result).to eq(30)
      end
    end

    describe "context binding" do
      it "executes proc in context via instance_exec" do
        context = Class.new do
          def helper
            "helper result"
          end
        end.new

        proc = -> { helper }
        plucky_proc = described_class.new(proc, context: context)

        result = plucky_proc.call({})

        expect(result).to eq("helper result")
      end

      it "executes proc with keywords in context" do
        context = Class.new do
          def format(text)
            "[#{text}]"
          end
        end.new

        proc = ->(message:) { format(message) }
        plucky_proc = described_class.new(proc, context: context)

        result = plucky_proc.call({message: "hello"})

        expect(result).to eq("[hello]")
      end

      it "calls Method directly without instance_exec" do
        context = Class.new do
          attr_accessor :value

          def compute(factor:)
            @value * factor
          end
        end.new
        context.value = 5

        method = context.method(:compute)
        plucky_proc = described_class.new(method, context: context)

        result = plucky_proc.call({factor: 3})

        expect(result).to eq(15)
      end
    end
  end

  describe "#callable?" do
    it "returns true when proc is present" do
      plucky_proc = described_class.new(-> {}, context: Object.new)

      expect(plucky_proc.callable?).to be true
    end

    it "returns false when proc is nil" do
      plucky_proc = described_class.new(nil, context: Object.new)

      expect(plucky_proc.callable?).to be false
    end
  end

  describe "#dependency_names" do
    it "returns empty array when no proc" do
      plucky_proc = described_class.new(nil, context: Object.new)

      expect(plucky_proc.dependency_names).to eq([])
    end

    it "returns required positional parameter names" do
      proc = ->(first, second) {}
      plucky_proc = described_class.new(proc, context: Object.new)

      expect(plucky_proc.dependency_names).to eq([:first, :second])
    end

    it "returns optional positional parameter names" do
      proc = ->(required, optional = nil) {}
      plucky_proc = described_class.new(proc, context: Object.new)

      expect(plucky_proc.dependency_names).to eq([:required, :optional])
    end

    it "excludes keyword parameters" do
      proc = ->(positional, keyword:) {}
      plucky_proc = described_class.new(proc, context: Object.new)

      expect(plucky_proc.dependency_names).to eq([:positional])
    end

    it "excludes rest parameters" do
      proc = ->(first, *rest) {}
      plucky_proc = described_class.new(proc, context: Object.new)

      expect(plucky_proc.dependency_names).to eq([:first])
    end
  end

  describe "#keyword_names" do
    it "returns empty array when no proc" do
      plucky_proc = described_class.new(nil, context: Object.new)

      expect(plucky_proc.keyword_names).to eq([])
    end

    it "returns required keyword parameter names" do
      proc = ->(first:, second:) {}
      plucky_proc = described_class.new(proc, context: Object.new)

      expect(plucky_proc.keyword_names).to eq([:first, :second])
    end

    it "returns optional keyword parameter names" do
      proc = ->(required:, optional: nil) {}
      plucky_proc = described_class.new(proc, context: Object.new)

      expect(plucky_proc.keyword_names).to eq([:required, :optional])
    end

    it "excludes positional parameters" do
      proc = ->(positional, keyword:) {}
      plucky_proc = described_class.new(proc, context: Object.new)

      expect(plucky_proc.keyword_names).to eq([:keyword])
    end

    it "excludes keyrest parameters" do
      proc = ->(named:, **rest) {}
      plucky_proc = described_class.new(proc, context: Object.new)

      expect(plucky_proc.keyword_names).to eq([:named])
    end
  end
end
