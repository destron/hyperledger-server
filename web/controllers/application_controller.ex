defmodule Hyperledger.ApplicationController do
  def log_entry_params(command, conn) do
    %{
      command: command,
      data: conn.private.raw_json_body,
      authentication_key: conn.assigns[:authentication_key],
      signature: conn.assigns[:signature]
    }
  end
end
