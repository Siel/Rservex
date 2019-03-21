defmodule Rservex.Connection do
  @cmd_eval 3
  @dt_string 4

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

  @spec send_message(port(), binary(), atom()) :: atom()
  def send_message(conn, data, type) do
    message = encode_message(data, type)
    :gen_tcp.send(conn, message)
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

  @spec header(integer(), integer()) :: <<_::128>>
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
