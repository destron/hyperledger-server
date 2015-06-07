defmodule Hyperledger.AssetController do
  use Hyperledger.Web, :controller
  import Hyperledger.ParamsHelpers
  
  alias Hyperledger.Repo
  alias Hyperledger.Asset
  alias Hyperledger.LogEntry

  plug Hyperledger.Authentication when action in [:create]
  plug :check_signature when action in [:create]
  plug :action

  def index(conn, _params) do
    assets = Repo.all(Asset)
    render conn, :index, assets: assets
  end
  
  def create(conn, params) do
    params =
      params
      |> underscore_keys
      |> Map.get("asset", :empty)
    changeset = Asset.changeset(%Asset{}, params)
    
    if changeset.valid? do
      log_params = log_entry_params("asset/create", conn)
      %LogEntry{}
      |> LogEntry.changeset(:create, log_params)
      |> LogEntry.create
      
      asset = Repo.get(Asset, params["hash"])
      
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
