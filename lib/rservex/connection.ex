defmodule Rservex.Connection do
  @cmd_eval 3
  @dt_string 4
  # define CMD_RESP 0x10000  /* all responses have this flag set */
  # define RESP_OK (CMD_RESP|0x0001) /* command succeeded; returned parameters depend on the command issued */
  # define RESP_ERR (CMD_RESP|0x0002) /* command failed, check stats code attached string may describe the error */
  @resp_ok 0x10001
  @resp_err 0x10002

  # all int and double entries throughout the transfer are encoded in Intel-endianess format:
  # int=0x12345678 -> char[4]=(0x78,0x56,x34,0x12)

  @doc """
  check if the response has a valid format according: https://www.rforge.net/Rserve/dev.html
  """
  @spec check_ack(port()) :: {:error, :invalid_ack} | {:ok, port()}
  def check_ack(conn) do
    {:ok, msg} = :gen_tcp.recv(conn, 32)

    case msg do
      <<"Rsrv", _version::size(32), _protocolor::size(32), _extra::binary>> ->
        {:ok, conn}

      _ ->
        {:error, :invalid_ack}
    end
  end

  @spec send_message(port(), any(), :eval) ::
          {:error, atom()} | {:ok, {:error, atom()} | {:ok, any()}}
  def send_message(conn, data, type) do
    message = encode_message(data, type)

    case :gen_tcp.send(conn, message) do
      :ok ->
        receive_reply(conn)

      {:error, error} ->
        {:error, error}
    end
  end

  def receive_reply(conn) do
    # recv(Socket, Length, Timeout)
    # Argument Length is only meaningful when the socket is in raw mode and denotes the number of bytes to read. If Length is 0, all available bytes are returned. If Length > 0, exactly Length bytes are returned
    {:ok, header} = :gen_tcp.recv(conn, 16)

    <<cmd_resp::little-32, length_low::little-32, _offset::little-32, length_high::little-32>> =
      header

    # The CMD_RESP mask is set for all responses. Each response consists of the response command (RESP_OK or RESP_ERR - least significant 24 bit) and the status code (most significant 8 bits).
    case cmd_resp do
      @resp_ok ->
        # left shift
        length = length_low + :erlang.bsl(length_high, 31)
        {:ok, receive_data(conn, length)}

      @resp_err ->
        # TODO: read error content
        {:error, :resp_err}

      _ ->
        raise("Unkwnown CMD_RESP")
    end
  end

  def receive_data(conn, len) do
    :gen_tcp.recv(conn, len)
  end

  def encode_message(data, :eval) do
    body = dt(data, :string)
    length = :erlang.iolist_size(body)
    [header(@cmd_eval, length), body]
  end

  # The header is structured as follows:

  # [0]  (int) 'command'
  # [4]  (int) 'length' of the message (bits 0-31)
  # [8]  (int) 'offset' of the data part
  # [12] (int) 'length' of the message (bits 32-63)
  # 'command' specifies the request or response type.
  # 'length' specifies the number of bytes belonging to this message (excluding the header).
  # 'offset' specifies the offset of the data part, where 0 means directly after the header (which is normally the case)
  # 'length2' high bits of the length (must be 0 if the packet size is smaller than 4GB)

  def header(command, length) do
    <<command::little-32, length::little-32, 0::little-32, 0::little-32>>
  end

  # The data part contains any additional parameters that are send along with the command. Each parameter consists of a 4-byte header:

  # [0]  (byte) type
  # [1]  (24-bit int) length
  # Types used by the current Rserve implementation (for list of all supported types see Rsrv.h):
  # DT_INT (4 bytes) integer
  # DT_STRING (n bytes) null terminated string
  # DT_BYTESTREAM (n bytes) any binary data
  # DT_SEXP R's encoded SEXP, see below
  # all int and double entries throughout the transfer are encoded in Intel-endianess format:
  # int=0x12345678 -> char[4]=(0x78,0x56,x34,0x12) functions/macros for converting from native to protocol format are available in Rsrv.h.

  # Rsrv.h:
  # define DT_STRING     4  /* 0 terminted string */

  def dt(string, :string) do
    string = transfer_string(string)
    length = :erlang.iolist_size(string)
    [<<@dt_string::little-8, length::little-24>>, string]
  end

  def transfer_string(string) do
    # According to Rsrv.h an dt_string type of transmision must terminate in 0
    [string, <<0>>]
  end
end
