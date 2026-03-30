defmodule TLX.Verifiers.EmptyActionTest do
  use ExUnit.Case

  import ExUnit.CaptureIO

  test "warns on empty action" do
    warnings =
      capture_io(:stderr, fn ->
        defmodule EmptyActionSpec do
          use TLX.Spec

          variable :x, 0

          action :do_nothing do
          end
        end
      end)

    assert warnings =~ "do_nothing" or warnings =~ "no transitions"
  end
end
