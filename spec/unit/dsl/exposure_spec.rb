# frozen_string_literal: true

RSpec.describe Hanami::Mailer::DSL::Exposure do
  describe "#initialize" do
    it "creates an exposure with a name" do
      exposure = described_class.new(:user)

      expect(exposure.name).to eq(:user)
    end

    it "creates an exposure with a proc" do
      proc = -> { "value" }
      exposure = described_class.new(:computed, proc)

      expect(exposure.callable).to be_a(Hanami::Mailer::DSL::PluckyProc)
    end

    it "creates an exposure with options" do
      exposure = described_class.new(:user, nil, nil, private: true, default: "fallback")

      expect(exposure.options).to eq({private: true, default: "fallback"})
    end
  end

  describe "#bind" do
    it "returns a new exposure bound to an object" do
      exposure = described_class.new(:user)
      context = Object.new

      bound = exposure.bind(context)

      expect(bound).to be_a(described_class)
      expect(bound.object).to eq(context)
    end

    it "preserves name and options when binding" do
      exposure = described_class.new(:user, nil, nil, private: true)
      context = Object.new

      bound = exposure.bind(context)

      expect(bound.name).to eq(:user)
      expect(bound.options).to eq({private: true})
    end

    it "creates callable from method when context responds to name" do
      context = Class.new do
        def my_exposure
          "from method"
        end
      end.new

      exposure = described_class.new(:my_exposure)
      bound = exposure.bind(context)

      expect(bound.callable).to be_a(Hanami::Mailer::DSL::PluckyProc)
    end
  end

  describe "#call" do
    describe "passthrough exposure (no proc)" do
      it "fetches value from input by name" do
        exposure = described_class.new(:user)
        input = {user: {name: "Alice"}, other: "ignored"}

        result = exposure.call(input)

        expect(result).to eq({name: "Alice"})
      end

      it "returns default value when key not in input" do
        exposure = described_class.new(:user, nil, nil, default: "default user")
        input = {other: "value"}

        result = exposure.call(input)

        expect(result).to eq("default user")
      end

      it "returns nil when key not in input and no default" do
        exposure = described_class.new(:user)
        input = {other: "value"}

        result = exposure.call(input)

        expect(result).to be_nil
      end
    end

    describe "computed exposure (with proc)" do
      it "evaluates proc with input keywords" do
        proc = ->(first_name:, last_name:) { "#{first_name} #{last_name}" }
        context = Object.new
        exposure = described_class.new(:full_name, proc, context)

        result = exposure.call({first_name: "John", last_name: "Doe"})

        expect(result).to eq("John Doe")
      end

      it "passes dependency values from locals" do
        proc = ->(user) { user[:name].upcase }
        context = Object.new
        exposure = described_class.new(:formatted_name, proc, context)

        result = exposure.call({}, {user: {name: "alice"}})

        expect(result).to eq("ALICE")
      end
    end
  end

  describe "#dependency_names" do
    it "returns empty array when no callable" do
      exposure = described_class.new(:user)

      expect(exposure.dependency_names).to eq([])
    end

    it "returns positional parameter names from proc" do
      proc = ->(order, user) {}
      exposure = described_class.new(:computed, proc, Object.new)

      expect(exposure.dependency_names).to eq([:order, :user])
    end
  end

  describe "#dependencies?" do
    it "returns false when no dependencies" do
      exposure = described_class.new(:user)

      expect(exposure.dependencies?).to be false
    end

    it "returns true when has dependencies" do
      proc = ->(other_exposure) {}
      exposure = described_class.new(:computed, proc, Object.new)

      expect(exposure.dependencies?).to be true
    end
  end

  describe "#private?" do
    it "returns false by default" do
      exposure = described_class.new(:user)

      expect(exposure.private?).to be false
    end

    it "returns true when private option is set" do
      exposure = described_class.new(:user, nil, nil, private: true)

      expect(exposure.private?).to be true
    end
  end

  describe "#default_value" do
    it "returns nil when no default" do
      exposure = described_class.new(:user)

      expect(exposure.default_value).to be_nil
    end

    it "returns default option value" do
      exposure = described_class.new(:user, nil, nil, default: "fallback")

      expect(exposure.default_value).to eq("fallback")
    end
  end

  describe "equality" do
    it "considers passthrough exposures equal when name, object, and options match" do
      context = Object.new

      exposure1 = described_class.new(:user, nil, context, private: true)
      exposure2 = described_class.new(:user, nil, context, private: true)

      expect(exposure1).to eq(exposure2)
    end

    it "considers exposures different when names differ" do
      exposure1 = described_class.new(:user)
      exposure2 = described_class.new(:order)

      expect(exposure1).not_to eq(exposure2)
    end

    it "considers exposures different when options differ" do
      exposure1 = described_class.new(:user, nil, nil, private: true)
      exposure2 = described_class.new(:user, nil, nil, private: false)

      expect(exposure1).not_to eq(exposure2)
    end
  end
end
