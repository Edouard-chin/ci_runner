# frozen_string_literal: true

require "rspec"

describe("harry potter") do
  context("abracadabra") do
    it("transforms") do
      expect("wand").to(eq("wand"))
    end

    it("flies") do
      expect("fly").to(eq("fly"))
    end

    it("not transforms") do
      boom
    end
  end
end
