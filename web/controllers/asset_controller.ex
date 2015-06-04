defmodule Hyperledger.AssetController do
  use Hyperledger.Web, :controller
  
  alias Hyperledger.Repo
  alias Hyperledger.Asset
  alias Hyperledger.LogEntry

  plug Hyperledger.Authentication when action in [:create]
  plug :action

  def index(conn, _params) do
    assets = Repo.all(Asset)
    render conn, :index, assets: assets
  end
  
  def create(conn, params) do
    log_params = log_entry_params("asset/create", conn)
    changeset = LogEntry.changeset(%LogEntry{}, :create, log_params)
    
    if changeset.valid? do
      LogEntry.create(changeset)
      asset = Repo.get(Asset, params["asset"]["hash"])
      conn
      |> put_status(:created)
      |> render :show, asset: asset
    else
      conn
      |> put_status(:unprocessable_entity)
      |> halt
    end
  end
end
