# SPDX-FileCopyrightText: 2026 Georges Martin
# SPDX-License-Identifier: MIT

defmodule TLX.SANYHelper do
  @moduledoc false

  @doc "Find tla2tools.jar via $TLA2TOOLS env var or standard fallback paths."
  def tla2tools_path do
    [
      System.get_env("TLA2TOOLS"),
      "tla2tools.jar",
      "docs/specs/tla2tools.jar",
      Path.expand("~/.tla2tools/tla2tools.jar")
    ]
    |> Enum.reject(&is_nil/1)
    |> Enum.find(&File.exists?/1)
  end

  @doc "Returns true if tla2tools.jar is available."
  def available?, do: tla2tools_path() != nil

  @doc "Run SANY parser on a .tla file. Returns {:ok, output} or {:error, output}."
  def sany_check(tla_path) do
    jar = tla2tools_path()

    {output, exit_code} =
      System.cmd("java", ["-cp", jar, "tla2sany.SANY", tla_path], stderr_to_stdout: true)

    if exit_code == 0, do: {:ok, output}, else: {:error, output}
  end

  @doc "Run pcal.trans on a .tla file containing PlusCal. Returns {:ok, output} or {:error, output}."
  def pcal_trans(tla_path) do
    jar = tla2tools_path()

    {output, exit_code} =
      System.cmd("java", ["-cp", jar, "pcal.trans", tla_path], stderr_to_stdout: true)

    if exit_code == 0, do: {:ok, output}, else: {:error, output}
  end

  @doc "Create a temp directory for test isolation. Returns path."
  def tmp_dir(prefix \\ "tlx_sany") do
    dir = Path.join(System.tmp_dir!(), "#{prefix}_#{:rand.uniform(100_000)}")
    File.mkdir_p!(dir)
    dir
  end
end
