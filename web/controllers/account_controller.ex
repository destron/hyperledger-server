defmodule Hyperledger.AccountController do
  use Hyperledger.Web, :controller
  import Hyperledger.ParamsHelpers
  
  alias Hyperledger.Repo
  alias Hyperledger.Account
  alias Hyperledger.LogEntry
  
  plug Hyperledger.Authentication when action in [:create]
  plug :check_signature when action in [:create]
  plug :action

  def index(conn, _params) do
    accounts = Repo.all(Account)
    render conn, :index, accounts: accounts
  end
  
  def show(conn, params) do
    account = Repo.get(Acccount, params["id"])
    render conn, :show, account: account
  end
  
  def create(conn, params) do
    params =
      params
      |> underscore_keys
      |> Map.get("account", :empty)
    changeset = Account.changeset(%Account{}, params, skip_db: true)
    
    if changeset.valid? do
      log_params = log_entry_params("account/create", conn)
      %LogEntry{}
      |> LogEntry.changeset(:create, log_params)
      |> LogEntry.create
      
      account = Repo.get(Account, params["public_key"])
      conn
      |> put_status(:created)
      |> render :show, account: account
    else
      conn
      |> put_status(:unprocessable_entity)
      |> halt
    end
  end
end
