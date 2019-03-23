defmodule Rservex.Connection do
  @cmd_eval 3
  @dt_string 4
  # define CMD_RESP 0x10000  /* all responses have this flag set */
  # define RESP_OK (CMD_RESP|0x0001) /* command succeeded; returned parameters depend on the command issued */
  # define RESP_ERR (CMD_RESP|0x0002) /* command failed, check stats code attached string may describe the error */
  @resp_ok 0x10001
  @resp_err 0x10002

  @dt_sexp 10

  @xt_arr_str 34

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

  def clear_buffer(conn) do
    :gen_tcp.recv(conn, 0, 1000)
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
        receive_data(conn, length)

      @resp_err ->
        # TODO: read error content
        {:error, :resp_err}

      resp_code ->
        IO.inspect(header)
        IO.inspect(length_low)
        # IO.inspect(:gen_tcp.recv(conn, 0, 1000))
        raise("Unkwnown CMD_RESP: " <> inspect(resp_code))
    end
  end

  def receive_data(conn, len) do
    case Enum.reverse(receive_data(conn, len, [])) do
      # Only one value received
      [val] ->
        val

      # multiple values received
      list ->
        list
    end
  end

  def receive_data(_conn, 0, acc) do
    acc
  end

  def receive_data(conn, len, acc) do
    {:ok, data_header} = :gen_tcp.recv(conn, 4)
    <<item_type::little-8, item_length::little-24>> = data_header
    item = receive_item(conn, item_type)
    acc = [item | acc]
    receive_data(conn, len - 4 - item_length, acc)
  end

  # R SEXP value (DT_SEXP) are recursively encoded in a similar way as the parameter attributes. Each SEXP consists of a 4-byte header and the actual contents. The header is of the form:
  # [0]  (byte) eXpression Type
  # [1]  (24-bit int) length
  def receive_item(conn, @dt_sexp) do
    {:ok, sexp_header} = :gen_tcp.recv(conn, 4)
    <<sexp_type::little-8, sexp_length::little-24>> = sexp_header
    receive_sexp(conn, sexp_type, sexp_length)
  end

  # The expression type consists of the actual type (least significant 6 bits) and attributes.
  # define XT_ARRAY_STR     34 /* P  data: string,string,.. (string=byte,byte,...,0) padded with '\01' */
  def receive_sexp(conn, @xt_arr_str, length) do
    receive_arr_str(conn, length)
  end

  def receive_sexp(conn, type, length) do
    IO.inspect(type)
    IO.inspect(length)
    clear_buffer(conn)
  end

  def receive_arr_str(_conn, 0) do
    {:xt_arr_str, ""}
  end

  def receive_arr_str(conn, length) do
    {:ok, data} = :gen_tcp.recv(conn, length)

    # Hacky code, only test purposes
    response =
      data
      |> String.replace(<<1>>, "")
      |> String.replace(<<0>>, "")
      |> String.codepoints()
      |> List.to_string()

    {:xt_arr_str, response}
  end

  # command           parameters            | response data
  # CMD_eval          DT_STRING or DT_SEXP  | DT_SEXP

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
