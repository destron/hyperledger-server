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
    log_entry = %{
      command: "asset/create",
      data: conn.private.raw_json_body,
      authentication_key: conn.assigns[:authentication_key],
      signature: conn.assigns[:signature]
    }
    changeset = LogEntry.changeset(%LogEntry{}, :create, log_entry)
    
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
