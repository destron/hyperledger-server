defmodule Hyperledger.CloseConfirmationController do
  use Hyperledger.Web, :controller
  
  alias Hyperledger.CloseConfirmation
  alias Hyperledger.Repo
  
  plug Hyperledger.Authentication
  plug :find_node_id
  plug :action
  
  def create(conn, params) do
    changeset = 
      %{
        node_id: conn.assigns[:node_id],
        view_id: params["closeConfirmation"]["viewId"],
        data: conn.private.raw_json_body,
        signature: conn.assigns[:signature]
      } |> CloseConfirmation.changeset

    if changeset.valid? do
      Repo.insert(changeset)
      send_resp(conn, 201, "")
    else
      IO.inspect changeset
      send_resp(conn, 422, "")
    end
  end
end
