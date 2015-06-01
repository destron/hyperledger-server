defmodule Hyperledger.CommitController do
  use Hyperledger.Web, :controller
  import Ecto.Query
  
  alias Hyperledger.Repo
  alias Hyperledger.CommitConfirmation, as: Commit
  alias Hyperledger.Node
  
  plug Hyperledger.Authentication
  plug :assign_node_id
  plug :action
  
  def create(conn, params) do
    changeset =
      %{
        data: conn.private.raw_json_body,
        signature: conn.assigns[:signature],
        node_id: conn.assigns[:node_id],
        log_entry_id: params["commit"]["id"]
      } |> Commit.changeset
    
    if changeset.valid? do
      Repo.insert(changeset)
      send_resp conn, 201, ""
    else
      conn
      |> put_status(:unprocessable_entity)
      |> halt
    end
  end
  
  defp assign_node_id(conn, _params) do
    key = conn.assigns[:authentication_key]
    node = Repo.one(from n in Node, where: n.public_key == ^key, select: n)
    if node do
      assign(conn, :node_id, node.id)
    else
      conn
      |> put_status(:forbidden)
      |> halt
    end
  end
end
