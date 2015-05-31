defmodule Hyperledger.TransferController do
  use Hyperledger.Web, :controller
  use Ecto.Model
  
  alias Hyperledger.Transfer
  alias Hyperledger.LogEntry
  alias Hyperledger.Repo
  
  plug Hyperledger.Authentication when action in [:create]
  plug :action

  def index(conn, _params) do
    transfers = Repo.all(Transfer)
    render conn, :index, transfers: transfers
  end
  
  def create(conn, params) do
    log_entry = %{
      command: "transfer/create",
      data: conn.private.raw_json_body,
      authentication_key: conn.assigns[:authentication_key],
      signature: conn.assigns[:signature]
    }
    changeset = LogEntry.changeset(%LogEntry{}, :create, log_entry)

    if changeset.valid? do
      LogEntry.create(changeset)
      transfer = Repo.get(Transfer, params["transfer"]["uuid"])
      conn
      |> put_status(:created)
      |> render :show, transfer: transfer
    else
      conn
      |> put_status(:unprocessable_entity)
      |> halt
    end
  end
end
