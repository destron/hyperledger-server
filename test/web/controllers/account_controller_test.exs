defmodule Hyperledger.AccountControllerTest do
  use Hyperledger.ConnCase
  
  alias Hyperledger.SecretStore
  
  alias Hyperledger.Account
  alias Hyperledger.LogEntry

  setup do
    create_primary
    {:ok, asset} = create_asset
    {:ok, asset: asset}
  end

  test "GET /accounts" do
    conn = get conn(), "/accounts"
    assert conn.status == 200
  end
  
  test "POST /accounts creates log entry and account", %{asset: asset} do
    {:ok, secret_store} = SecretStore.start_link
    params = account_params(asset.hash, secret_store)
    
    public_key = params.account[:publicKey]
    secret_key = SecretStore.get(secret_store, public_key)
    sig = sign(params, secret_key) |> Base.encode16
    
    conn = conn()
       |> put_req_header("content-type", "application/json")
       |> put_req_header("authorization", "Hyper Key=#{public_key}, Signature=#{sig}")
       |> post("/accounts", Poison.encode!(params))
    
    assert conn.status == 201
    assert Repo.all(Account)  |> Enum.count == 2
    assert Repo.all(LogEntry) |> Enum.count == 1
  end
end
