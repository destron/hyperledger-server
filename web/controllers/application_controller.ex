defmodule Hyperledger.ApplicationController do
  # use Hyperledger.Web, :controller
  import Plug.Conn
  import Ecto.Query
  
  alias Hyperledger.Node
  alias Hyperledger.Repo
  
  def log_entry_params(command, conn) do
    %{
      command: command,
      data: conn.private.raw_json_body,
      authentication_key: conn.assigns[:authentication_key],
      signature: conn.assigns[:signature]
    }
  end
  
  def find_node_id(conn, _params) do
    find_by_public_key = from n in Node,
                       where: n.public_key == ^conn.assigns[:authentication_key],
                      select: n
    case Repo.one(find_by_public_key) do
      nil ->
        conn |> put_status(:unauthorized) |> halt
      node ->
        assign(conn, :node_id, node.id)
    end
  end
end
