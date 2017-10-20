defmodule ElixirLS.Utils.WireProtocol do
  @moduledoc """
  Reads and writes packets using the Language Server Protocol's wire protocol
  """
  alias ElixirLS.Utils.{PacketStream, OutputDevice}

  def send(packet) do
    pid = Process.whereis(:raw_user) || Process.group_leader()
    body = Poison.encode!(packet) <> "\r\n\r\n"
    IO.binwrite(pid, "Content-Length: #{byte_size(body)}\r\n\r\n" <> body)
  end

  def io_intercepted? do
    !!Process.whereis(:raw_user)
  end

  def intercept_output(print_fn, print_err_fn) do
    raw_user = Process.whereis(:user)
    raw_standard_error = Process.whereis(:standard_error)
    :io.setopts(raw_user, binary: true, encoding: :latin1)

    {:ok, user} = OutputDevice.start_link(raw_user, print_fn)
    {:ok, standard_error} = OutputDevice.start_link(raw_standard_error, print_err_fn)

    Process.unregister(:user)
    Process.register(raw_user, :raw_user)
    Process.register(user, :user)

    Process.unregister(:standard_error)
    Process.register(raw_standard_error, :raw_standard_error)
    Process.register(standard_error, :standard_error)

    for process <- :erlang.processes,
        not(process in [raw_user, raw_standard_error]) do
      Process.group_leader(process, user)
    end
  end

  def stream_packets(receive_packets_fn) do
    PacketStream.stream(Process.whereis(:raw_user))
    |> Stream.each(fn packet -> receive_packets_fn.(packet) end)
    |> Stream.run
  end
end
