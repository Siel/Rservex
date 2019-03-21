defmodule Rservex do
  @moduledoc """
  Rservex is an elixir wrapper of del's erserver erlang implementation
  """

  @host "localhost"
  @port 6311

  ## HANDLE CONNECTION____________________________________________

  @doc """
  Opens a connection

  returns a port that identifies the connection

  ## Examples

      iex> Rservex.open()
      #Port<>

  """

  def open(params \\ []) do
    case params do
      [] ->
        open(host: @host, port: @port)

      [host: host] ->
        open(host: host, port: @port)

      [port: port] ->
        open(host: @host, port: port)

      [host: host, port: port] ->
        _open(host |> to_charlist(), port)

      _ ->
        {:error, :invalid_params}
    end
  end

  defp _open(host, port) do
    # active: If the value is false (passive mode), the process must explicitly receive incoming data by calling gen_tcp:recv/2,3, gen_udp:recv/2,3, or gen_sctp:recv/1,2 (depending on the type of socket).
    # binary: Received Packet is delivered as a binary.
    # packet: Defines the type of packets to use for a socket. Possible values: raw | 0 No packaging is done.
    {:ok, conn} = :gen_tcp.connect(host, port, [:binary, active: false, packet: :raw])

    case Rservex.Connection.check_ack(conn) do
      {:ok, conn} ->
        conn

      {:error, _} ->
        close(conn)
        raise("Invalid ACk")
    end
  end

  @doc """
  Closes a connection

  ## Examples

      iex> Rservex.close(conn)
      :ok

  """
  @spec close(port()) :: atom()
  def close(conn) when is_port(conn) do
    conn
    |> :gen_tcp.close()
  end

  # R STUFF _____________________________________________

  @doc """
  Evals an expression
  returns a tuple

  {:ok, {:type, val}}
  """
  def eval(conn, expression) do
    Rservex.Connection.send_message(conn, expression, :eval)
  end
end
