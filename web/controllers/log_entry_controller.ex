defmodule Hyperledger.LogEntryController do
  use Hyperledger.Web, :controller
  import Hyperledger.ParamsHelpers, only: [underscore_keys: 1]
  
  alias Hyperledger.Repo
  alias Hyperledger.LogEntry
  alias Hyperledger.PrePrepare
  alias Hyperledger.View
  alias Hyperledger.Node
  
  plug Hyperledger.Authentication when action in [:create]
  plug :halt_if_forbidden when action in [:create]
  plug :action

  def index(conn, _params) do
    entries = Repo.all(LogEntry)
    render conn, :index, entries: entries
  end
  
  def create(conn, params) do
    params = underscore_keys(params["logEntry"])
    log_changeset = LogEntry.changeset(%LogEntry{}, :insert, params)
    pre_prepare_changeset =
      %{
        data: conn.private.raw_json_body,
        signature: conn.assigns[:signature],
        node_id: View.current.primary.id,
        log_entry_id: params["id"]
      } |> PrePrepare.changeset
    
    if log_changeset.valid? and pre_prepare_changeset.valid? do
      Repo.insert(log_changeset)
      Repo.insert(pre_prepare_changeset)
      send_resp conn, 201, ""
    else
      conn
      |> send_resp(422, "" )
      |> halt
    end
  end
  
  defp halt_if_forbidden(conn, _params) do
    forbidden? =
      Node.current == View.current.primary or
      conn.assigns[:authentication_key] != View.current.primary.public_key
    
    if forbidden? do
      conn
      |> put_status(:forbidden)
      |> halt
    else
      conn
    end
  end
end
