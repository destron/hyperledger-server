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
    log_params = log_entry_params("transfer/create", conn)
    changeset = LogEntry.changeset(%LogEntry{}, :create, log_params)
    
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
