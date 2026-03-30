defmodule TLX.Emitter.UnicodeTest do
  use ExUnit.Case

  alias TLX.Emitter.Unicode

  Code.require_file("examples/mutex.ex", File.cwd!())
  Code.require_file("examples/producer_consumer.ex", File.cwd!())

  describe "Unicode pretty-printer" do
    test "uses mathematical symbols" do
      output = Unicode.emit(Examples.Mutex)

      assert output =~ "≜"
      assert output =~ "∧"
      assert output =~ "∨"
      assert output =~ "¬"
      assert output =~ "′"
      assert output =~ "⟨"
      assert output =~ "⟩"
    end

    test "uses temporal operators" do
      output = Unicode.emit(Examples.Mutex)

      assert output =~ "□(◇(pc1 = cs))"
    end

    test "uses decorative header and footer" do
      output = Unicode.emit(Examples.Mutex)

      assert output =~ "──── MODULE Mutex ────"
      assert output =~ "════"
    end

    test "formats producer-consumer" do
      output = Unicode.emit(Examples.ProducerConsumer)

      assert output =~ "buf_size′ = buf_size + 1"
      assert output =~ "≤"
      assert output =~ "≥"
    end
  end
end
