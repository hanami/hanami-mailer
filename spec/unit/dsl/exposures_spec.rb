# frozen_string_literal: true

RSpec.describe Hanami::Mailer::DSL::Exposures do
  describe "#initialize" do
    it "creates empty collection by default" do
      exposures = described_class.new

      expect(exposures).to be_empty
    end

    it "accepts initial exposures hash" do
      exposure = Hanami::Mailer::DSL::Exposure.new(:name, nil)
      exposures = described_class.new({name: exposure})

      expect(exposures.key?(:name)).to be true
    end
  end

  describe "#add" do
    it "adds an exposure by name" do
      exposures = described_class.new
      exposures.add(:user)

      expect(exposures.key?(:user)).to be true
      expect(exposures[:user]).to be_a(Hanami::Mailer::DSL::Exposure)
    end

    it "adds an exposure with a proc" do
      exposures = described_class.new
      exposures.add(:greeting) { |name:| "Hello, #{name}!" }

      expect(exposures[:greeting]).to be_a(Hanami::Mailer::DSL::Exposure)
    end

    it "adds an exposure with options" do
      exposures = described_class.new
      exposures.add(:internal, nil, private: true)

      expect(exposures[:internal].private?).to be true
    end
  end

  describe "#key?" do
    it "returns true when exposure exists" do
      exposures = described_class.new
      exposures.add(:user)

      expect(exposures.key?(:user)).to be true
    end

    it "returns false when exposure does not exist" do
      exposures = described_class.new

      expect(exposures.key?(:nonexistent)).to be false
    end
  end

  describe "#[]" do
    it "returns exposure by name" do
      exposures = described_class.new
      exposures.add(:user)

      expect(exposures[:user]).to be_a(Hanami::Mailer::DSL::Exposure)
      expect(exposures[:user].name).to eq(:user)
    end

    it "returns nil for nonexistent exposure" do
      exposures = described_class.new

      expect(exposures[:nonexistent]).to be_nil
    end
  end

  describe "#each" do
    it "iterates over all exposures" do
      exposures = described_class.new
      exposures.add(:first)
      exposures.add(:second)

      names = []
      exposures.each { |name, _| names << name }

      expect(names).to eq([:first, :second])
    end
  end

  describe "#empty?" do
    it "returns true when no exposures" do
      exposures = described_class.new

      expect(exposures.empty?).to be true
    end

    it "returns false when exposures exist" do
      exposures = described_class.new
      exposures.add(:user)

      expect(exposures.empty?).to be false
    end
  end

  describe "#dup" do
    it "creates independent copy" do
      original = described_class.new
      original.add(:user)

      copy = original.dup
      copy.add(:order)

      expect(original.key?(:order)).to be false
      expect(copy.key?(:user)).to be true
      expect(copy.key?(:order)).to be true
    end

    it "deep copies exposure objects" do
      original = described_class.new
      original.add(:user)

      copy = original.dup

      expect(copy[:user]).not_to be(original[:user])
    end
  end

  describe "#bind" do
    it "returns new Exposures with bound exposures" do
      exposures = described_class.new
      exposures.add(:greeting) { "Hello!" }

      context = Object.new
      bound = exposures.bind(context)

      expect(bound).to be_a(described_class)
      expect(bound).not_to be(exposures)
    end
  end

  describe "#call" do
    describe "simple exposures" do
      it "evaluates passthrough exposures from input" do
        exposures = described_class.new
        exposures.add(:user)
        exposures.add(:order)

        context = Object.new
        bound = exposures.bind(context)
        result = bound.call({user: "Alice", order: 123})

        expect(result).to eq({user: "Alice", order: 123})
      end

      it "evaluates computed exposures" do
        exposures = described_class.new
        exposures.add(:user)
        exposures.add(:greeting, ->(user:) { "Hello, #{user}!" })

        context = Object.new
        bound = exposures.bind(context)
        result = bound.call({user: "Alice"})

        expect(result).to eq({user: "Alice", greeting: "Hello, Alice!"})
      end
    end

    describe "dependency ordering" do
      it "evaluates exposures in dependency order" do
        exposures = described_class.new
        exposures.add(:base)
        exposures.add(:derived, ->(base) { base * 2 })
        exposures.add(:final, ->(derived) { derived + 1 })

        context = Object.new
        bound = exposures.bind(context)
        result = bound.call({base: 5})

        expect(result[:base]).to eq(5)
        expect(result[:derived]).to eq(10)
        expect(result[:final]).to eq(11)
      end

      it "handles complex dependency chains" do
        exposures = described_class.new
        exposures.add(:a)
        exposures.add(:b, ->(a) { a + 1 })
        exposures.add(:c, ->(a, b) { a + b })
        exposures.add(:d, ->(c) { c * 2 })

        context = Object.new
        bound = exposures.bind(context)
        result = bound.call({a: 1})

        expect(result).to eq({a: 1, b: 2, c: 3, d: 6})
      end

      it "handles exposures with no dependencies efficiently" do
        exposures = described_class.new
        exposures.add(:first)
        exposures.add(:second)
        exposures.add(:third)

        context = Object.new
        bound = exposures.bind(context)
        result = bound.call({first: 1, second: 2, third: 3})

        expect(result).to eq({first: 1, second: 2, third: 3})
      end
    end

    describe "private exposures" do
      it "removes private exposures from result" do
        exposures = described_class.new
        exposures.add(:user)
        exposures.add(:internal, nil, private: true)
        exposures.add(:derived) { |internal:| internal.upcase }

        context = Object.new
        bound = exposures.bind(context)
        result = bound.call({user: "Alice", internal: "secret"})

        expect(result.key?(:user)).to be true
        expect(result.key?(:derived)).to be true
        expect(result.key?(:internal)).to be false
      end

      it "still allows private exposures as dependencies" do
        exposures = described_class.new
        exposures.add(:multiplier, nil, private: true)
        exposures.add(:value)
        exposures.add(:result, ->(multiplier, value) { multiplier * value })

        context = Object.new
        bound = exposures.bind(context)
        result = bound.call({multiplier: 3, value: 10})

        expect(result).to eq({value: 10, result: 30})
        expect(result.key?(:multiplier)).to be false
      end
    end

    describe "with block" do
      it "yields each value and exposure to block" do
        exposures = described_class.new
        exposures.add(:count)

        yielded = []
        context = Object.new
        bound = exposures.bind(context)
        bound.call({count: 5}) do |value, exposure|
          yielded << [value, exposure.name]
          value * 2
        end

        expect(yielded).to eq([[5, :count]])
      end

      it "uses block return value in result" do
        exposures = described_class.new
        exposures.add(:value)

        context = Object.new
        bound = exposures.bind(context)
        result = bound.call({value: 10}) { |v, _| v * 2 }

        expect(result[:value]).to eq(20)
      end
    end
  end

  describe "#import" do
    it "adds an existing exposure" do
      exposures = described_class.new
      exposure = Hanami::Mailer::DSL::Exposure.new(:imported, -> { "value" })

      exposures.import(:imported, exposure)

      expect(exposures.key?(:imported)).to be true
    end

    it "duplicates the exposure" do
      exposures = described_class.new
      exposure = Hanami::Mailer::DSL::Exposure.new(:imported, nil)

      exposures.import(:imported, exposure)

      expect(exposures[:imported]).not_to be(exposure)
    end
  end

  describe "equality" do
    it "considers exposures equal when they have same exposures" do
      exposures1 = described_class.new
      exposures1.add(:user)

      exposures2 = described_class.new
      exposures2.add(:user)

      expect(exposures1).to eq(exposures2)
    end
  end
end
